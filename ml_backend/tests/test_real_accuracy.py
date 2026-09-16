"""Uji _real_accuracy: hanya menghitung sinyal yang data_source != 'synthetic'."""
import pandas as pd
from main import _real_accuracy


def _df(start_close: float = 100.0, days: int = 10):
    closes = [start_close + i for i in range(days)]
    idx = pd.date_range("2026-09-07", periods=days, freq="D")
    return pd.DataFrame({"Close": closes}, index=idx)


def test_skips_synthetic():
    df = _df()
    log = [
        {"symbol": "XAUUSD", "date": "2026-09-08", "action": "BUY", "data_source": "synthetic"},
        {"symbol": "XAUUSD", "date": "2026-09-09", "action": "BUY"},
    ]
    r = _real_accuracy(log, "XAUUSD", df)
    assert r["samples"] == 1, r
    assert r["win_rate"] == 1.0, "09-08 LEWAT, hanya 09-09 BUY dihitung, next day up -> win=1"


def test_includes_live():
    df = _df()
    log = [
        {"symbol": "XAUUSD", "date": "2026-09-09", "action": "BUY", "data_source": "live"},
        {"symbol": "XAUUSD", "date": "2026-09-10", "action": "SELL", "data_source": "live"},
    ]
    r = _real_accuracy(log, "XAUUSD", df)
    assert r["samples"] == 2


def test_ignores_other_symbols():
    df = _df()
    log = [
        {"symbol": "NASDAQ", "date": "2026-09-09", "action": "BUY"},
        {"symbol": "XAUUSD", "date": "2026-09-10", "action": "BUY"},
    ]
    r = _real_accuracy(log, "XAUUSD", df)
    assert r["samples"] == 1
