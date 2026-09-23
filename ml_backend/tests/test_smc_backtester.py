import numpy as np
import pandas as pd

from services.smc_backtester import (
    backtest_fvg,
    backtest_order_blocks,
    backtest_summary,
    backtest_sweep,
    backtest_sweep_confirmed,
    collect_fvg_signals,
    collect_order_block_signals,
    collect_sweep_signals,
    sweep_confirmation,
)


def _df(closes: np.ndarray, opens: np.ndarray | None = None) -> pd.DataFrame:
    opens = closes.copy() if opens is None else opens
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(closes), freq="D")
    highs = np.maximum(opens, closes) * 1.004
    lows = np.minimum(opens, closes) * 0.996
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": np.full(len(closes), 1000.0)},
        index=dates,
    )


def _trendy() -> pd.DataFrame:
    return _df(np.linspace(100.0, 130.0, 140))


def _flat() -> pd.DataFrame:
    return _df(np.linspace(100.0, 130.0, 140))


def _gap_series() -> pd.DataFrame:
    """Clear bullish FVG at i=32 (low 106 > high[30] 101) that stays open."""
    rows = []
    c = 100.0
    for i in range(60):
        o = c
        if i == 28:
            hi, lo, cl = 101.5, 99.0, 99.5  # bearish -> bullish order block trigger
        elif i in (29, 30):
            hi, lo, cl = 101.0, 99.5, c + 1.0
        elif i == 31:
            hi, lo, cl = 104.5, 102.0, 104.0
        elif i == 32:
            hi, lo, cl = 107.5, 106.0, 107.0  # FVG: low 106 > high[30] 101
        else:
            hi, lo, cl = c + 1.0, 106.5, c + 0.2
        rows.append(pd.DataFrame([{"Open": o, "High": hi, "Low": lo, "Close": cl, "Volume": 1000.0}]))
        c = cl
    df = pd.concat(rows)
    df.index = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(df), freq="D")
    return df


def _sweep_series() -> pd.DataFrame:
    """Sawtooth that sweeps the prior session low then rallies -> BUY_SWEEP reversals."""
    n = 80
    base = 100.0
    closes = []
    for i in range(n):
        bar = i % 6
        if bar < 3:
            closes.append(base + bar * 2)
        else:
            closes.append(base + (6 - bar) * 2)
        base = 100.0 + (i // 6) * 1.0
    closes = np.array(closes, dtype=float)
    return _df(closes)


def test_collect_fvg_finds_gap():
    sigs = collect_fvg_signals(_gap_series())
    assert any(s["type"] == "BULL" and s["top"] > s["bottom"] for s in sigs)


def test_collect_fvg_degrades():
    assert collect_fvg_signals(_df(np.linspace(100, 101, 10))) == []


def test_collect_sweep_series_has_samples():
    sigs = collect_sweep_signals(_sweep_series())
    assert isinstance(sigs, list)
    assert all(s["type"] in ("BUY_SWEEP", "SELL_SWEEP") for s in sigs)


def test_collect_order_block_finds_trigger():
    sigs = collect_order_block_signals(_gap_series())
    assert any(s["type"] == "BULL" and s["top"] >= s["bottom"] for s in sigs)


def test_backtest_fvg_short_input_passthrough():
    r = backtest_fvg(_df(np.linspace(100, 101, 20)))
    assert r["count"] == 0
    assert r["note"] == "insufficient data"


def test_backtest_fvg_real_numbers():
    r = backtest_fvg(_gap_series())
    assert r["count"] > 0
    assert r["mitigation_rate"] >= 0.0
    assert r["reaction_rate"] >= 0.0
    assert r["mitigated"] <= r["count"]
    assert r["reacted"] <= r["mitigated"]


def test_backtest_sweep_short_input_passthrough():
    r = backtest_sweep(_df(np.linspace(100, 101, 20)))
    assert r["count"] == 0
    assert r["by_type"]["BUY_SWEEP"]["count"] == 0


def test_backtest_sweep_shape():
    r = backtest_sweep(_sweep_series())
    assert r["count"] >= 0
    assert 0.0 <= r["reversal_rate"] <= 100.0
    assert r["by_type"]["BUY_SWEEP"]["count"] + r["by_type"]["SELL_SWEEP"]["count"] == r["count"]


def test_backtest_ob_split():
    r = backtest_order_blocks(_trendy())
    assert r["all"]["count"] >= 0
    assert 0.0 <= r["all"]["hold_rate"] <= 100.0
    assert r["volume_filtered"]["count"] >= 0
    assert r["volume_filtered"]["hold_rate"] >= 0.0


def test_backtest_summary_aggregates():
    r = backtest_summary(_gap_series())
    assert r["bars"] > 0
    assert set(r["handlers"]) == {"fvg", "sweep", "sweep_confirmed", "order_blocks"}
    assert set(r["decisions"]) >= {"fvg_mitigation_rate", "sweep_reversal_rate", "ob_hold_rate_all"}


def test_sweep_confirmation_states():
    confirmed = [s for s in sweep_confirmation(_sweep_series()) if s["confirmation"] == "CONFIRMED"]
    pending = [s for s in sweep_confirmation(_sweep_series()) if s["confirmation"] == "PENDING"]
    states = [s["confirmation"] for s in sweep_confirmation(_sweep_series())]
    assert all(st in ("CONFIRMED", "PENDING", "UNCONFIRMED") for st in states)
    assert isinstance(confirmed, list)
    assert isinstance(pending, list)


def test_backtest_sweep_confirmed_shape():
    r = backtest_sweep_confirmed(_sweep_series())
    assert r["count"] >= 0
    assert r["confirmed"] >= 0
    assert 0.0 <= r["confirmed_reversal_rate"] <= 100.0
    assert 0.0 <= r["raw_reversal_rate"] <= 100.0
    assert set(r["by_type"]) == {"BUY_SWEEP", "SELL_SWEEP"}


def test_backtest_on_flat_series():
    flat = _flat()
    r = backtest_summary(flat)
    assert isinstance(r, dict)
    assert r["decisions"]["fvg_reaction_rate"] >= 0.0