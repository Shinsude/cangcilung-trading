import numpy as np
import pandas as pd

from services.institutional import cvd_divergence, futures_basis, volume_profile


def _df(n: int = 140) -> pd.DataFrame:
    rng = np.random.default_rng(7)
    closes = 100.0 * np.exp(np.cumsum(rng.normal(0.0004, 0.01, n)))
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    highs = closes * 1.004
    lows = closes * 0.996
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    vols = rng.integers(1000, 9000, n).astype(float)
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": vols},
        index=dates,
    )


def _trend_df(n: int = 140) -> pd.DataFrame:
    closes = np.linspace(100.0, 120.0, n)
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    highs = closes + 0.3
    lows = closes - 0.3
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    vols = np.full(n, 1000.0)
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": vols},
        index=dates,
    )


def _basis_pair(tail_shift: float = 0.0, tail: int = 30, n: int = 140):
    """Future vs physical pair; shift moves the last ``tail`` rows of the ratio."""
    f = np.linspace(100.0, 120.0, n)
    s = f.copy()
    s[-tail:] = s[-tail:] * (1.0 + tail_shift)
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    return (
        pd.DataFrame({"Close": f}, index=dates),
        pd.DataFrame({"Close": s}, index=dates),
    )


def _rise_price_fall_flow() -> pd.DataFrame:
    """Price net higher over lookback while cumulative delta is lower → BEARISH."""
    closes = np.concatenate(
        [
            np.full(40, 100.0),
            np.array(
                [99.5, 99.4, 99.3, 99.2, 99.1, 99.0, 98.9, 98.8, 99.2, 99.6, 100.0, 100.01, 100.02, 100.03]
            ),
        ]
    )
    n = len(closes)
    dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    highs = closes + 0.2
    lows = closes - 0.2
    opens = np.roll(closes, 1)
    opens[0] = closes[0]
    vols = np.ones(n) * 100.0
    # Down-days (8 bars) carry heavy volume vs faint up-days.
    for i in range(n - 14, n - 6):
        vols[i] = 600.0
    return pd.DataFrame(
        {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": vols},
        index=dates,
    )


def test_volume_profile_structure():
    vp = volume_profile(_df())
    assert vp is not None
    assert vp["val"] <= vp["poc"] <= vp["vah"]
    assert vp["price_pos"] in ("ABOVE", "INSIDE", "BELOW")
    assert 0.0 <= vp["range_pos_pct"] <= 100.0


def test_volume_profile_short_frame():
    assert volume_profile(_df(20)) is None
    assert volume_profile(None) is None


def test_cvd_divergence_none_on_clean_trend():
    assert cvd_divergence(_trend_df()) == "NONE"


def test_cvd_divergence_bearish():
    assert cvd_divergence(_rise_price_fall_flow(), lookback=14) == "BEARISH"


def test_cvd_divergence_small_frame():
    assert cvd_divergence(_df(10)) in ("NONE", "BULLISH", "BEARISH")


def test_futures_basis_premium():
    f, s = _basis_pair(tail_shift=-0.02)  # physical drops at the end -> futures rich
    b = futures_basis(f, s)
    assert b is not None
    assert b["state"] == "PREMIUM"
    assert b["last_pct"] > 0


def test_futures_basis_discount():
    f, s = _basis_pair(tail_shift=0.02)  # physical pops -> futures cheap
    b = futures_basis(f, s)
    assert b is not None
    assert b["state"] == "DISKONTO"
    assert b["last_pct"] < 0


def test_futures_basis_neutral():
    f, s = _basis_pair(tail_shift=0.0)  # stable relationship
    b = futures_basis(f, s)
    assert b is not None
    assert b["state"] == "NETRAL"


def test_futures_basis_degradation():
    assert futures_basis(None, None) is None
    assert futures_basis(_df(), None) is None
    assert futures_basis(None, _df()) is None
    short = _basis_pair(n=40)
    assert futures_basis(*short) is None  # not enough history for the baseline