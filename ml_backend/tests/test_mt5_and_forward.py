"""Hermetic tests: konektor MT5 (tanpa terminal) + forward-test (tanpa network)."""
import numpy as np
import pandas as pd

from services import forward_test as ft
from services import mt5_data as mt


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


def test_update_seed_then_no_dup(tmp_path):
    logp = tmp_path / "ft.csv"
    df = _forward_fixture()
    s1 = ft.update(df, log_path=str(logp), seed=True)
    assert s1["new"] > 0
    s2 = ft.update(df, log_path=str(logp), seed=False)
    assert s2["new"] == 0
    assert s2["rows"] == s1["rows"]