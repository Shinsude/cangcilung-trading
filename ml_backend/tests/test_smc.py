import numpy as np
import pandas as pd

from services.smc import (
    fvg,
    liquidity,
    order_blocks,
    premium_discount,
    smc_context,
    structure,
    swing_points,
)


def _df(closes: np.ndarray, opens: np.ndarray | None = None) -> pd.DataFrame:
    opens = closes.copy() if opens is None else opens
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(closes), freq="D")
    highs = np.maximum(opens, closes) * 1.004
    lows = np.minimum(opens, closes) * 0.996
    vols = np.full(len(closes), 1000.0)
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": vols},
        index=dates,
    )


def _stock_like() -> pd.DataFrame:
    closes = np.linspace(100.0, 130.0, 140)
    return _df(closes)


def _fiat() -> pd.DataFrame:
    closes = np.linspace(150.0, 110.0, 140)
    return _df(closes)


def _swingy() -> pd.DataFrame:
    """Deterministic zig-zag so fractals exist every ~5 bars."""
    base = 100.0
    n = 140
    vals = []
    step = 2.0
    for i in range(n):
        phase = (i // 5) % 2
        if phase == 0:
            vals.append(base + step * (i % 5))
        else:
            vals.append(base + step * (5 - (i % 5)))
    closes = np.array(vals, dtype=float)
    return _df(closes)


def _gap_series() -> pd.DataFrame:
    """Manual OHLC with a clear bullish FVG that stays open, preceded by a bearish candle.

    Candle i=28 is the last bearish candle before the impulse (order block).
    Candle i=32 gaps up: low[32] > high[30] forms a bullish FVG that later bars
    never re-enter (unmitigated).
    """
    rows = []
    c = 100.0
    for i in range(60):
        o = c
        if i == 28:  # bearish candle -> bullish order block for the impulse after it
            hi, lo, cl = 101.5, 99.0, 99.5
        elif i in (29, 30):
            hi, lo, cl = 101.0, 99.5, c + 1.0  # small bullish ramp
        elif i == 31:
            hi, lo, cl = 104.5, 102.0, 104.0
        elif i == 32:
            hi, lo, cl = 107.5, 106.0, 107.0  # FVG: low 106 > high[30] 101
        else:  # stays above 106 -> gap unmitigated
            hi, lo, cl = c + 1.0, 106.5, c + 0.2
        row = pd.DataFrame(
            [{"Open": o, "High": hi, "Low": lo, "Close": cl, "Volume": 1000.0}]
        )
        rows.append(row)
        c = cl
    df = pd.concat(rows)
    df.index = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(df), freq="D")
    return df


def test_swing_points_shape():
    sw = swing_points(_swingy())
    assert sw["n"] == 140
    assert isinstance(sw["highs"], list)
    assert any(np.isfinite(p) for _, p in sw["highs"])
    for i, _ in sw["highs"]:
        assert 1 <= i <= sw["n"] - 3


def test_structure_uptrend():
    s = structure(_stock_like())
    assert s["trend"] in ("BULLISH", "BEARISH", "NEUTRAL")
    assert s["breakout"] in ("BULLISH", "BEARISH", None)


def test_swingy_structure_has_levels():
    s = structure(_swingy())
    assert s["swing_high"] is not None
    assert s["swing_low"] is not None
    assert s["swing_high_bars_ago"] >= 0


def test_fvg_bullish_detected_and_unmitigated():
    r = fvg(_gap_series())
    assert r["bullish"] is not None
    assert r["bullish"]["top"] > r["bullish"]["bottom"]
    assert isinstance(r["bullish"]["age_days"], int)


def test_fvg_degradation():
    short = _df(np.linspace(100, 101, 10))
    assert fvg(short) == {"bullish": None, "bearish": None}


def test_order_blocks_follow_fvg():
    obs = order_blocks(_gap_series())
    assert obs["bullish"] is not None
    assert obs["bullish"]["top"] >= obs["bullish"]["bottom"]


def test_liquidity_structure():
    lid = liquidity(_swingy())
    assert set(lid) == {"pdh", "pdl", "sweep", "sweep_type"}
    assert lid["pdh"] is not None
    assert lid["sweep"] in ("NONE", "SELL_SWEEP", "BUY_SWEEP", "BOTH")


def test_premium_discount_zone():
    pd_ = premium_discount(_swingy())  # price inside the range around equilibrium
    assert pd_["equilibrium"] is not None
    assert pd_["pct"] is not None
    assert pd_["pos"] in ("PREMIUM", "DISKONTO", "NETRAL")


def test_smc_context_full():
    ctx = smc_context(_gap_series())
    assert ctx is not None
    assert ctx["available"] is True
    assert ctx["bias"] in ("LEAN_BULLISH", "LEAN_BEARISH", "NETRAL")
    assert "note" in ctx
    assert ctx["structure"]["trend"] in ("BULLISH", "BEARISH", "NEUTRAL")


def test_smc_context_none_short():
    assert smc_context(None) is None
    assert smc_context(_df(np.linspace(100, 102, 20))) is None