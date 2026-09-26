"""Unit test pipeline intraday tanpa network (fetch di-mock)."""
import sys
import numpy as np
import pandas as pd

from services import intraday_research as ir


def _fake_df(n=400) -> pd.DataFrame:
    closes = np.full(n, 100.0)
    closes[30] = 105.0
    closes[40:50] = np.linspace(103.0, 101.0, 10)
    closes[50] = 94.0
    closes[51:70] = np.linspace(94.0, 104.0, 19)
    closes[70] = 107.0
    closes[71:] = np.linspace(107.0, 109.0, n - 71)
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="h")
    return pd.DataFrame(
        {
            "Open": opens,
            "High": np.maximum(opens, closes) * 1.008,
            "Low": np.minimum(opens, closes) * 0.992,
            "Close": closes,
            "Volume": np.full(n, 1000.0),
        },
        index=dates,
    )


def test_run_intraday_shape(monkeypatch):
    monkeypatch.setattr(ir, "fetch_intraday", lambda **kw: _fake_df())
    r = ir.run_intraday(interval="60m", period="1mo")
    assert r["bars"] == 400
    assert r["interval"] == "60m"
    assert set(r["is"]) == {"signals", "filled", "fill_rate", "wins", "losses",
                            "win_rate", "gross_profit_r", "gross_loss_r",
                            "profit_factor", "avg_r", "exits"}
    assert r["is"]["filled"] <= r["is"]["signals"]


def test_run_intraday_no_data(monkeypatch):
    monkeypatch.setattr(ir, "fetch_intraday", lambda **kw: None)
    r = ir.run_intraday(interval="30m", period="1mo")
    assert r["note"] == "no intraday data"
    assert r["bars"] == 0


def test_infraday_params_include_sl_bars():
    assert "sl_bars" in ir.INTRADAY_PARAMS
    assert ir.INTRADAY_PARAMS["retest_lookahead"] >= 1
    assert ir.INTRADAY_PARAMS["rr"] > 1.0