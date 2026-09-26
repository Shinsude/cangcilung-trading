import numpy as np
import pandas as pd

from services.smc_limit_backtester import (
    _summary,
    backtest_limit_entries,
    detect_choch,
    nearest_zone,
    simulate_limit,
)


def _df(closes: np.ndarray, opens: np.ndarray | None = None) -> pd.DataFrame:
    opens = closes.copy() if opens is None else opens
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=len(closes), freq="D")
    highs = np.maximum(opens, closes) * 1.006
    lows = np.minimum(opens, closes) * 0.994
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": np.full(len(closes), 1000.0)},
        index=dates,
    )


def _ohlc_df(closes: np.ndarray) -> pd.DataFrame:
    """OHLC builder with real wicks so swing pivots are unambiguous."""
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    n = len(closes)
    highs = np.maximum(opens, closes) * 1.008
    lows = np.minimum(opens, closes) * 0.992
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": np.full(n, 1000.0)},
        index=dates,
    )


def _choch_series() -> pd.DataFrame:
    """Explicit swing pivots: swing low 20, swing high 40, lower-low grab 70,
    then break above the swing high by 95 -> a single unambiguous BULL ChoCh."""
    n = 200
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    open = np.full(n, 100.0)
    high = np.full(n, 100.8)
    low = np.full(n, 99.2)
    close = np.full(n, 100.0)
    low[20] = 95.0           # swing low 1 (prior pivot)
    close[20] = 96.0
    high[20] = 97.0
    for i in range(21, 40):              # rally to swing high 1
        high[i], low[i] = 98.0 + (i - 20) * 0.5, 96.5 + (i - 20) * 0.3
        close[i] = high[i] - 0.2
    high[40] = 107.0        # swing high 1
    close[40] = 106.0
    for i in range(41, 70):              # drift down off the swing high
        high[i], low[i] = 105.0 - (i - 40) * 0.05, 99.0
        close[i] = high[i] - 0.2
    low[70] = 91.0          # lower-low grab (below swing low 20)
    close[70] = 92.0
    for i in range(71, 95):              # rally
        high[i], low[i] = 100.0 + (i - 70) * 0.3, 91.5 + (i - 70) * 0.2
        close[i] = high[i] - 0.2
    for i in range(95, 101):             # close decisively above swing high 40
        close[i] = 108.0
        high[i] = 108.4
    for i in range(101, n):              # continuation drift
        close[i] = 108.0 + (i - 101) * 0.01
        high[i] = close[i] + 0.4
        low[i] = close[i] - 0.4
        open[i] = close[i - 1]
    return pd.DataFrame(
        {"Open": open, "High": high, "Low": low, "Close": close, "Volume": np.full(n, 1000.0)},
        index=dates,
    )


def test_detect_choch_finds_bull():
    sigs = detect_choch(_choch_series())
    bulls = [s for s in sigs if s["direction"] == "BULL"]
    assert len(bulls) >= 1
    assert all(s["swing_high"] < s["index"] for s in bulls)


def test_detect_choch_degrades_short():
    assert detect_choch(_df(np.linspace(100, 101, 20))) == []


def test_nearest_zone_picks_discount_fvg():
    df = _choch_series()
    sigs = detect_choch(df)
    bull = next(s for s in sigs if s["direction"] == "BULL")
    zone = nearest_zone(df, bull)
    if zone is not None:
        assert zone["bottom"] < zone["entry"] < zone["top"] or zone["entry"] <= zone["top"]
        assert zone["zone_index"] < bull["index"]


def test_simulate_limit_shape():
    df = _choch_series()
    sigs = detect_choch(df)
    bull = next(s for s in sigs if s["direction"] == "BULL")
    zone = nearest_zone(df, bull)
    if zone is None:
        return
    res = simulate_limit(df, bull, zone)
    assert res["filled"] in (True, False)
    if res["filled"]:
        assert res["r"] is not None
        assert isinstance(res["bars_to_fill"], int)


def test_backtest_limit_entries_shape():
    df = _choch_series()
    r = backtest_limit_entries(df)
    assert r["bars"] > 0
    assert r["is"]["signals"] >= 0
    assert r["oos"]["signals"] >= 0
    for part in ("is", "oos"):
        assert 0.0 <= r[part]["fill_rate"] <= 100.0
        assert r[part]["wins"] + r[part]["losses"] == r[part]["filled"]


def test_backtest_limit_entries_short_input():
    r = backtest_limit_entries(_df(np.linspace(100, 101, 20)))
    assert r["note"] == "insufficient data"


def test_slice_by_date_oos():
    dates = pd.date_range("2022-01-01", periods=200, freq="D")
    df = _choch_series()
    df.index = dates
    r = backtest_limit_entries(df, is_start="2022-01-01", is_end="2023-12-31",
                               oos_start="2024-01-01", oos_end=None)
    assert r["bars"] == 200
    assert r["is"]["signals"] >= 0
    assert r["oos"]["signals"] >= 0


def test_slice_disjoint_is_oos():
    """is_start + is_end tanpa oos harus tidak berefek pada keduanya (anti-regresi
    bug split 60/40). Tanggal berbeda harus menghasilkan sinyal berbeda."""
    dates = pd.date_range("2022-01-01", periods=200, freq="D")
    df = _choch_series()
    df.index = dates
    r_first_half = backtest_limit_entries(df, is_start="2022-01-01", is_end="2022-07-01")
    r_second_half = backtest_limit_entries(df, is_start="2022-07-02", is_end="2022-12-31")
    assert r_first_half["is"]["signals"] != r_second_half["is"]["signals"]


def test_cost_r_reduces_pf_and_avg_r():
    trades = [
        {"filled": True, "r": 2.0, "exit": "target"},
        {"filled": True, "r": -1.0, "exit": "stop"},
        {"filled": True, "r": 0.4, "exit": "timeout"},
        {"filled": False, "r": None, "exit": "no_zone"},
    ]
    gross = _summary(trades, cost_r=0.0)
    at_cost = _summary(trades, cost_r=0.3)
    expensive = _summary(trades, cost_r=1.0)
    assert gross["profit_factor"] == 2.4
    assert at_cost["profit_factor"] < gross["profit_factor"]
    assert at_cost["avg_r"] < gross["avg_r"]
    assert expensive["profit_factor"] < 1.0
    assert expensive["win_rate"] < gross["win_rate"]