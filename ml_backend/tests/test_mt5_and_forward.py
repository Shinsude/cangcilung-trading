"""Hermetic tests: konektor MT5 (tanpa terminal) + forward-test (tanpa network)."""
import numpy as np
import pandas as pd

from services import forward_test as ft
from services import mt5_data as mt
from services.smc_limit_backtester import simulate_limit


def _rates_df() -> pd.DataFrame:
    seconds = int(pd.Timestamp("2024-01-01").timestamp()) + 1800 * np.arange(100)
    return pd.DataFrame(
        {
            "time": seconds,
            "open": np.arange(100, 200, dtype=float),
            "high": np.arange(100, 200, dtype=float) + 1.0,
            "low": np.arange(100, 200, dtype=float) - 1.0,
            "close": np.arange(100, 200, dtype=float) + 0.5,
            "tick_volume": np.full(100, 500),
            "spread": np.zeros(100),
            "real_volume": np.zeros(100),
        }
    )


def test_tf_map_has_expected_keys():
    for tf in ("M5", "M15", "M30", "H1", "H4", "D1", "W1"):
        assert tf in mt.TF_MAP


def test_clean_mt5_converts_time_and_columns():
    df = mt._clean_mt5(_rates_df())
    assert not df.empty
    assert list(df.columns) == ["Open", "High", "Low", "Close", "Volume"]
    assert str(df.index[0]) == "2024-01-01 00:00:00"
    assert float(df["Close"].iloc[-1]) == 199.5


def test_clean_mt5_missing_time_returns_empty():
    df = _rates_df().drop(columns=["time"])
    assert mt._clean_mt5(df).empty


def test_fetch_unknown_timeframe():
    assert mt.fetch_mt5("XAUUSD", "M7") is None


def _forward_fixture() -> pd.DataFrame:
    """Seri zigzag SMC bersih: SL1(100) -> SH1(110) -> SL2(98) -> FVG -> choch."""
    def legs(a, b, mult=8):
        return np.linspace(a, b, max(2, int(abs(b - a) * mult)) + 1)[:-1]

    closes, highs, lows = [], [], []
    for c in (*legs(105, 100), *legs(100, 110), *legs(110, 98)):
        closes.append(c)
        highs.append(c + 0.3)
        lows.append(c - 0.3)
    closes += [98.4, 102.0, 110.5]
    highs += [99.2, 102.5, 111.0]
    lows += [98.1, 100.2, 102.3]
    for c in legs(110.5, 114):
        closes.append(c)
        highs.append(c + 0.3)
        lows.append(c - 0.3)
    opens = np.roll(np.array(closes), 1)
    opens[0] = closes[0]
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(closes), freq="30min")
    return pd.DataFrame(
        {"Open": opens, "High": np.array(highs), "Low": np.array(lows),
         "Close": np.array(closes), "Volume": np.ones(len(closes))},
        index=dates,
    )


def test_build_records_return_levels():
    recs = ft.build_records(_forward_fixture())
    assert recs
    r = recs[0]
    for key in ("signal_time", "zone_time", "direction", "entry", "sl", "tp", "rr"):
        assert key in r
    assert r["tp"] > r["entry"] if r["direction"] == "BUY" else r["tp"] < r["entry"]


def test_status_mapping():
    assert ft._status_from({"filled": False, "exit": "not_filled"}) == ("no_fill", None)
    assert ft._status_from({"filled": False, "exit": "no_future"}) == ("pending", None)
    assert ft._status_from({"filled": True, "exit": "target", "r": 2.0}) == ("target", 2.0)
    assert ft._status_from({"filled": True, "exit": "stop", "r": -1.0}) == ("stop", -1.0)


def test_update_seed_then_no_dup(tmp_path, monkeypatch):
    # fixture pendek: bias harian & sesi tak terpenuhi -> buka filter dulu
    monkeypatch.setattr(ft, "SESSION_UTC", (0, 24))
    monkeypatch.setattr(ft, "passes_bias", lambda t, direction, bias: True)
    logp = tmp_path / "ft.csv"
    df = _forward_fixture()
    s1 = ft.update(df, log_path=str(logp), seed=True)
    assert s1["new"] > 0
    s2 = ft.update(df, log_path=str(logp), seed=False)
    assert s2["new"] == 0
    assert s2["rows"] == s1["rows"]


def test_update_resolves_row_reloaded_from_csv(tmp_path):
    """Baris pending dari CSV (parse_dates -> Timestamp) harus bisa ter-resolve.

    Regresi: key outcome berbentuk str sehingga lookup dengan Timestamp selalu
    None dan semua sinyal 60m mandek di 'pending' selamanya.
    """
    df = _forward_fixture()
    recs = ft.build_records(df)
    assert recs
    outcome = ft.outcomes_map(df, recs)
    decided = [r for r in recs if ft._status_from(outcome[r["signal_time"]])[0] != "pending"]
    assert decided, "fixture harus punya minimal satu sinyal terdecide"
    r = decided[0]

    logp = tmp_path / "ft.csv"
    pd.DataFrame(
        [{
            "signal_time": r["signal_time"],
            "zone_time": r["zone_time"],
            "direction": r["direction"],
            "entry": r["entry"],
            "sl": r["sl"],
            "tp": r["tp"],
            "rr": r["rr"],
            "found_at": "2026-01-01 00:00:00",
            "status": "pending",
            "resolved_at": "",
            "r": None,
        }]
    ).to_csv(logp, index=False)

    res = ft.update(df, log_path=str(logp))
    assert res["resolved"] >= 1
    after = pd.read_csv(logp)
    row = after[after["signal_time"].astype(str) == r["signal_time"]].iloc[0]
    assert row["status"] != "pending"
    assert row["resolved_at"] != ""


def test_passes_bias_follows_prior_day_trend():
    bias = pd.Series([5.0, -3.0], index=pd.to_datetime(["2026-01-05", "2026-01-06"]))
    # sinyal 07 Jan: pakai nilai 06 Jan (-3) -> BUY ditolak, SELL diterima
    assert not ft.passes_bias(pd.Timestamp("2026-01-07 05:00"), "BUY", bias)
    assert ft.passes_bias(pd.Timestamp("2026-01-07 05:00"), "SELL", bias)
    # hari penuh sebelum sinyal saja: nilai 06 Jan tidak dipakai utk sinyal tgl 06
    assert not ft.passes_bias(pd.Timestamp("2026-01-06 23:00"), "SELL", bias)
    assert ft.passes_bias(pd.Timestamp("2026-01-06 23:00"), "BUY", bias)
    # tanpa riwayat -> tolak
    assert not ft.passes_bias(pd.Timestamp("2026-01-04 05:00"), "BUY", bias)


def test_in_session_window():
    assert ft.in_session(pd.Timestamp("2026-01-01 00:00"))
    assert ft.in_session(pd.Timestamp("2026-01-01 11:59"))
    assert not ft.in_session(pd.Timestamp("2026-01-01 12:00"))
    assert not ft.in_session(pd.Timestamp("2026-01-01 23:00"))


def test_update_applies_session_and_bias_filters(tmp_path, monkeypatch):
    df = _forward_fixture()
    monkeypatch.setattr(ft, "SESSION_UTC", (0, 24))
    monkeypatch.setattr(ft, "passes_bias", lambda t, direction, bias: True)
    opened = ft.update(df, log_path=str(tmp_path / "open.csv"), seed=True)

    monkeypatch.setattr(ft, "SESSION_UTC", (24, 25))  # jendela selalu tertutup
    closed = ft.update(df, log_path=str(tmp_path / "closed.csv"), seed=True)
    assert opened["new"] > 0
    assert closed["new"] == 0


def test_summary_empty_log(tmp_path):
    s = ft.summary(log_path=str(tmp_path / "none.csv"))
    assert s["rows"] == 0
    assert s["note"] == "log kosong"


def test_summary_metrics_and_gate(tmp_path):
    logp = tmp_path / "ft.csv"
    pd.DataFrame(
        {
            "signal_time": [f"2026-01-0{i % 9 + 1}" for i in range(30)],
            "found_at": ["2026-01-01"] * 30,
            "resolved_at": [""] * 30,
            "status": ["target"] * 12 + ["stop"] * 8 + ["timeout"] * 5 + ["no_fill"] * 3 + ["pending"] * 2,
            "r": [2.0] * 12 + [-1.0] * 8 + [0.3, 0.1, -0.2, 0.5, -0.4] + [None] * 5,
        }
    ).to_csv(logp, index=False)
    small = ft.summary(log_path=str(logp), min_resolved=100)
    assert small["note"].startswith("belum cukup")
    full = ft.summary(log_path=str(logp), min_resolved=20)
    assert full["n_resolved"] == 25
    assert full["win_rate_decided"] == 60.0
    assert full["n_decided"] == 20
    assert full["avg_r"] > 0
    assert full["note"] == "forward-test, bukan alpha terbukti"
    direct = ft.summarize_df(pd.read_csv(logp), min_resolved=20)
    assert direct["n_resolved"] == 25
    assert direct["win_rate_decided"] == 60.0
    assert direct["avg_r"] == full["avg_r"]


def test_forward_json_serializable():
    import json

    from main import _sanitize_json

    df = pd.DataFrame(
        {
            "signal_time": pd.to_datetime(["2026-01-01"]),
            "found_at": pd.to_datetime(["2026-01-01"]),
            "resolved_at": pd.to_datetime([pd.NaT]),
            "status": ["pending"],
            "r": [np.nan],
        }
    )
    record = _sanitize_json(df.to_dict("records"))
    assert record[0]["resolved_at"] is None
    assert record[0]["r"] is None
    assert record[0]["signal_time"] == "2026-01-01T00:00:00Z"
    body = json.loads(json.dumps(ft.summarize_df(df, min_resolved=5)))
    assert body["rows"] == 1


def _bull_path(post_lows, post_highs):
    """20 bar datar sebelum sinyal (SL=95 di index 5) lalu path sesudahnya."""
    lows = [100.0] * 21
    lows[5] = 95.0
    highs = [103.0] * 21
    closes = [102.0] * 21
    lows += list(post_lows)
    highs += list(post_highs)
    closes += [(l + h) / 2 for l, h in zip(post_lows, post_highs)]
    opens = [closes[0]] + closes[:-1]
    idx = pd.date_range("2026-01-01", periods=len(lows), freq="h")
    return pd.DataFrame({"Open": opens, "High": highs, "Low": lows, "Close": closes},
                        index=idx)


_CHOCH = {"index": 20, "direction": "BULL"}
_ZONE = {"entry": 100.0}          # risk = 100 - 95 = 5, tp = 110 (rr 2)


def test_simulate_limit_be_converts_stop_to_breakeven():
    df = _bull_path([99.0, 102.0, 94.0], [103.0, 105.5, 104.0])
    plain = simulate_limit(df, _CHOCH, _ZONE, lookahead=10)
    assert plain["exit"] == "stop" and plain["r"] == -1.0
    # harga menyentuh +1R (105) lebih dulu -> SL pindah ke entry, lalu kena di 94
    be = simulate_limit(df, _CHOCH, _ZONE, lookahead=10, be_trigger_r=1.0)
    assert be["exit"] == "be" and be["r"] == 0.0


def test_simulate_limit_partial_target_and_stop():
    df = _bull_path([99.0, 102.0, 104.0], [103.0, 105.5, 111.0])
    full = simulate_limit(df, _CHOCH, _ZONE, lookahead=10)
    assert full["exit"] == "target" and full["r"] == 2.0
    part = simulate_limit(df, _CHOCH, _ZONE, lookahead=10, partial_trigger_r=1.0)
    assert part["exit"] == "target"
    assert part["r"] == 1.5           # 50% di +1R + 50% di +2R

    df2 = _bull_path([99.0, 102.0, 94.0], [103.0, 105.5, 104.0])
    part_stop = simulate_limit(df2, _CHOCH, _ZONE, lookahead=10, partial_trigger_r=1.0)
    assert part_stop["exit"] == "stop"
    assert part_stop["r"] == 0.0      # 50% di +1R + 50% di -1R


def test_status_mapping_includes_be():
    assert ft._status_from({"filled": True, "exit": "be", "r": 0.0}) == ("be", 0.0)