"""Test deterministik modul riset backtest ketat (services/research.py)."""
import numpy as np
import pandas as pd

from services import research
from services.backtest import run


def _make_df(n: int = 130, seed: int = 11, base: float = 2500.0) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    x = np.arange(n)
    closes = base + x * 1.8 + 8.0 * np.sin(x / 11.0) + rng.normal(0, 1.2, n)
    closes = np.clip(closes, base * 0.5, base * 2.0)
    opens = closes + rng.normal(0, 0.6, n)
    highs = np.maximum(opens, closes) + rng.uniform(0, 1.6, n)
    lows = np.minimum(opens, closes) - rng.uniform(0, 1.6, n)
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


def test_strict_run_shape():
    df = _make_df()
    out = research.strict_run(df)
    for key in ("trades", "win_rate", "total_return", "max_drawdown", "profit_factor"):
        assert key in out
    assert isinstance(out["win_rate"], float)


def test_strict_less_or_equal_trades_than_relaxed():
    df = _make_df()
    strict = research.strict_run(df)
    relaxed = run(df)
    assert strict["trades"] <= relaxed["trades"]


def test_regime_breakdown_rows():
    df = _make_df()
    rows = research.regime_breakdown(df)
    assert isinstance(rows, list)
    for row in rows:
        assert set(row) >= {"regime", "trades", "win_rate", "total_return", "max_drawdown"}
        assert row["samples"] == row["trades"]


def test_sensitivity_rows():
    df = _make_df()
    rows = research.sensitivity(df)
    assert len(rows) == 5
    for row in rows:
        assert set(row) >= {"buy_th", "trades", "win_rate", "total_return", "max_drawdown", "quality"}
    ths = [r["buy_th"] for r in rows]
    assert ths == sorted(ths)


def test_summary_contract():
    df = _make_df()
    out = research.summary(df)
    for key in ("data_points", "current_regime", "cost_model", "relaxed", "strict", "difference", "by_regime", "sensitivity"):
        assert key in out
    assert out["difference"]["trades"] == out["strict"]["trades"] - out["relaxed"]["trades"]
    for row in out["by_regime"]:
        assert "is_current" in row
    assert any(row["is_current"] for row in out["by_regime"])


def test_current_regime_direct():
    df = _make_df()  # profil naik dominan
    regime = research.current_regime(df)
    assert regime["label"] in ("TRENDING_UP", "TRENDING_DOWN", "TEKANAN", "PELEMAHAN", "CHOPPY")
    assert isinstance(regime["efficiency"], float)


def test_summary_on_sliced_days():
    df = _make_df(n=130)
    out = research.summary(df.tail(45))
    assert out["data_points"] <= 45
    assert out["current_regime"]["label"] in ("TRENDING_UP", "TRENDING_DOWN", "TEKANAN", "PELEMAHAN", "CHOPPY")