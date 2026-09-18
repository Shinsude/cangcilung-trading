"""Test deterministik analisis struktur pasar (services/market_analysis.py)."""
import numpy as np
import pandas as pd

from services.indicators import compute_all
from services.market_analysis import analyze_market


def _make_df(profile: str, n: int = 120, seed: int = 7, base: float = 2500.0) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    x = np.arange(n)
    if profile == "up":
        closes = base + x * 2.0 + rng.normal(0, 1.0, n)
    elif profile == "down":
        closes = base + 300.0 - x * 2.0 + rng.normal(0, 1.0, n)
    elif profile == "choppy":
        walk = np.cumsum(rng.normal(0, 1.5, n))
        closes = base + walk - np.mean(walk)
    elif profile == "peak":  # naik lalu turun (dua puncak) — potensi divergensi
        closes = base + 150.0 * np.sin(x / 24.0) * np.exp(-((x - 60) ** 2) / 900) + rng.normal(0, 1.0, n)
    else:
        raise ValueError(profile)
    closes = np.clip(closes, base * 0.5, base * 2.0)
    opens = closes + rng.normal(0, 0.5, n)
    highs = np.maximum(opens, closes) + rng.uniform(0, 1.5, n)
    lows = np.minimum(opens, closes) - rng.uniform(0, 1.5, n)
    return pd.DataFrame(
        {
            "Open": opens,
            "High": highs,
            "Low": lows,
            "Close": closes,
            "Volume": rng.integers(1_000, 10_000, n),
        },
        index=pd.date_range("2025-01-01", periods=n, freq="D"),
    )


def _analyze(profile: str, action: str = "BUY"):
    df = _make_df(profile)
    ind = compute_all(df)
    return df, ind, analyze_market(df, ind, {"action": action}, decimals=2)


def test_uptrend_regime():
    _, ind, m = _analyze("up")
    assert m["available"] is True
    assert m["regime"]["label"] == "TRENDING_UP"


def test_downtrend_regime():
    _, ind, m = _analyze("down")
    assert m["regime"]["label"] == "TRENDING_DOWN"


def test_choppy_regime():
    _, ind, m = _analyze("choppy")
    assert m["regime"]["label"] == "CHOPPY"


def test_levels_support_below_resistance_above():
    df, ind, m = _analyze("up")
    price = ind["price"]
    lev = m["levels"]
    if lev["nearest_support"] is not None:
        assert lev["nearest_support"] < price
    if lev["nearest_resistance"] is not None:
        assert lev["nearest_resistance"] > price
    assert lev["pivot"] > 0


def test_plan_exits_for_buy():
    _, ind, m = _analyze("up", action="BUY")
    plan = m["plan"]
    assert plan["side"] == "BUY"
    assert plan["sl"] < ind["price"] < plan["tp1"]
    assert plan["tp2"] > plan["tp1"]
    assert plan["risk_reward"] is not None and abs(plan["risk_reward"] - 1.0) < 0.01


def test_plan_exits_for_sell():
    _, ind, m = _analyze("down", action="SELL")
    plan = m["plan"]
    assert plan["side"] == "SELL"
    assert plan["sl"] > ind["price"] > plan["tp1"]
    assert plan["risk_reward"] is not None and abs(plan["risk_reward"] - 1.0) < 0.01


def test_confirmations_bounded():
    _, ind, m = _analyze("up", action="BUY")
    c = m["confirmations"]
    assert 0 <= c["concurrence"] <= 1
    assert 0 < c["total"] <= len(c["items"])
    assert c["agreeing"] <= c["total"]
    for it in c["items"]:
        assert set(it) >= {"label", "direction", "agree"}


def test_divergence_well_formed():
    _, ind, m = _analyze("peak", action="BUY")
    d = m["divergence"]
    assert d["rsi"] in ("NONE", "BULLISH", "BEARISH")
    assert d["macd"] in ("NONE", "BULLISH", "BEARISH")


def test_explain_bullets():
    _, ind, m = _analyze("up", action="BUY")
    out = m["explain"]
    assert isinstance(out, list) and len(out) >= 4
    assert all(isinstance(line, str) and line for line in out)


def test_short_data_unavailable():
    df = _make_df("up", n=20)
    ind = compute_all(df)
    m = analyze_market(df, ind, {"action": "HOLD"}, decimals=2)
    assert m["available"] is False