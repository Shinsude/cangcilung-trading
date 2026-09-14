"""Test deterministik service backend tanpa network/kunci eksternal.

Jangan mengimpor main.py di sini (memuat yfinance/FastAPI berat); uji
logika murni service yang bisa diverifikasi tanpa fetch data.
"""
import math

import numpy as np
import pandas as pd

from services import backtest
from services.data_service import DataService
from services.signal import build_signal, DEFAULT_THRESHOLDS
from services.predictor import predict


def _flat_ind(direction: str = "UP", signal_bias: float = 0.0):
    """Indikator minimal agar build_signal bisa dihitung penuh."""
    bearish = direction == "DOWN"
    return {
        "price": 100.0,
        "atr": 1.0,
        "rsi": {"value": 50.0, "region": "neutral"},
        "macd": {"cross": "neutral", "histogram": 0.0},
        "ema": {
            "trend": "bearish" if bearish else "bullish",
            "ema9": (90.0 if bearish else 95.0),
            "ema21": (92.0 if bearish else 94.0),
            "ema50": 93.0,
        },
        "bollinger": {"percent_b": 0.5, "upper": 110.0, "lower": 90.0},
        "volume": 0.0,
        "sr": 0.5,
        "signal_bias": signal_bias,
    }


class _Sent:
    score: float = 0.0
    label: str = "NEUTRAL"
    bull: float = 0.0


def _predict(up: bool = True, confidence: float = 0.8):
    closes = np.linspace(100.0, 101.5 if up else 98.5, 50)
    df = pd.DataFrame(
        {"Open": closes, "High": closes, "Low": closes, "Close": closes, "Volume": [1] * len(closes)},
        index=pd.date_range("2026-01-01", periods=len(closes), freq="D"),
    )
    clamp = min(0.95, max(0.05, confidence))
    pred = {"next_price": float(closes[-1]), "horizon": "6 jam", "direction": "UP" if up else "DOWN", "confidence": clamp, "ensembles": 5}
    return closes, pred, df


def test_build_signal_hold():
    ind = _flat_ind()
    pred = {"direction": "NEUTRAL", "confidence": 0.1}
    out = build_signal(ind, pred, {"score": 0.0, "label": "NEUTRAL"})
    assert out["action"] in ("HOLD", "BUY", "SELL")
    assert "action" in out and "strength" in out and "confidence" in out


def test_build_signal_bullish_predicts_buy():
    ind = _flat_ind(direction="UP")
    pred = {"direction": "UP", "confidence": 0.9}
    out = build_signal(ind, pred, {"score": 0.0, "label": "NEUTRAL"})
    assert out["action"] == "BUY"


def test_build_signal_bearish_predicts_sell():
    ind = _flat_ind(direction="DOWN")
    pred = {"direction": "DOWN", "confidence": 0.9}
    out = build_signal(ind, pred, {"score": 0.0, "label": "NETRAL"})
    assert out["action"] == "SELL"


def test_synthetic_fallback_shape_and_source(monkeypatch):
    ds = DataService()
    df = ds._synthetic("XAUUSD")
    assert len(df) == 140
    assert list(df.columns) == ["Open", "High", "Low", "Close", "Volume"]
    assert not df.isnull().values.any()

    # source() sebelum fetch apa pun -> default "live"
    assert ds.source("XAUUSD") == "live"

    # Patch _download -> None agar fetch memakai fallback sintetik & menandai source
    monkeypatch.setattr(ds, "_download", lambda *a, **k: None)
    df2 = ds.fetch("XAUUSD", ttl=30)
    assert len(df2) > 0
    assert ds.source("XAUUSD") == "synthetic"


def test_predict_output_shape():
    closes, pred, df = _predict(up=True, confidence=0.8)
    result = predict(closes, df=df)
    assert "next_price" in result
    assert "direction" in result
    assert "confidence" in result
    assert 0.0 <= result["confidence"] <= 1.0


def test_backtest_returns_curve():
    closes, _, df = _predict(up=True, confidence=0.6)
    res = backtest.run(df)
    for key in ("win_rate", "profit_factor", "total_return", "max_drawdown", "trades", "quality"):
        assert key in res
    assert isinstance(res.get("win_rate"), float)


def test_equity_curve_bounded():
    closes, _, df = _predict(up=True, confidence=0.6)
    res = backtest.run(df)
    curve = res.get("equity_curve", [])
    assert isinstance(curve, list)
    assert len(curve) > 0
    for pt in curve:
        assert pt["equity"] > 0