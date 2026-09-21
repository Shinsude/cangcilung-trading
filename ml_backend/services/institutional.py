"""Institutional-flavour context derived from daily data (honest proxies).

These helpers model where institutional liquidity concentrates using only the
daily OHLCV series available from yfinance. They deliberately do NOT pretend to
be real order-flow data — everything here is an estimate from price/volume.
"""
import numpy as np
import pandas as pd

VOLUME_PROFILE_LOOKBACK = 126  # ~6 months of trading days
VALUE_AREA_PCT = 0.70
VP_BINS = 48
CVD_DIVERGENCE_LOOKBACK = 14
BASIS_AVG_LOOKBACK = 20
BASIS_BASELINE_LOOKBACK = 60
BASIS_PREMIUM_BAND_PCT = 0.5  # +/- band around the rolling physical-place ratio


def volume_profile(
    df: pd.DataFrame | None,
    lookback: int = VOLUME_PROFILE_LOOKBACK,
    bins: int = VP_BINS,
) -> dict | None:
    """Point of Control / Value Area from daily volume-at-price distribution.

    Returns None when the series is too short or volume is unavailable so the
    consumer can degrade gracefully.
    """
    if df is None or len(df) < 30 or "Volume" not in df:
        return None
    df = df.tail(lookback)
    lows = df["Low"].astype(float).to_numpy()
    highs = df["High"].astype(float).to_numpy()
    vols = df["Volume"].astype(float).to_numpy()
    lo = float(np.nanmin(lows))
    hi = float(np.nanmax(highs))
    if not np.isfinite(lo) or not np.isfinite(hi) or not hi > lo:
        return None

    edges = np.linspace(lo, hi, bins + 1)
    mid = (edges[:-1] + edges[1:]) / 2.0
    profile = np.zeros(bins)

    for i in range(len(df)):
        vol = float(vols[i])
        if not vol > 0:
            continue
        covered = (mid >= lows[i]) & (mid <= highs[i])
        if covered.any():
            profile[covered] += vol / float(covered.sum())
        else:
            b = int(np.searchsorted(edges, (lows[i] + highs[i]) / 2.0, side="left") - 1)
            profile[max(0, min(bins - 1, b))] += vol

    total = float(profile.sum())
    if not total > 0 or not np.isfinite(total):
        return None

    poc_idx = int(np.argmax(profile))
    poc = float(mid[poc_idx])

    # Value area: greedily expand outward from POC until VALUE_AREA_PCT of volume.
    order = sorted(range(bins), key=lambda i: abs(i - poc_idx))
    acc = 0.0
    left = right = poc_idx
    for i in order:
        acc += float(profile[i])
        left = min(left, i)
        right = max(right, i)
        if acc / total >= VALUE_AREA_PCT:
            break

    vah = float(mid[right])
    val = float(mid[left])
    if not vah > val:
        return None

    price = float(df["Close"].iloc[-1])
    if price <= 0:
        return None

    if val <= price <= vah:
        pos = "INSIDE"
    elif price > vah:
        pos = "ABOVE"
    else:
        pos = "BELOW"

    return {
        "poc": round(poc, 5),
        "vah": round(vah, 5),
        "val": round(val, 5),
        "price": round(price, 5),
        "price_pos": pos,
        "va_width_pct": round((vah - val) / price * 100.0, 2),
        "poc_dist_pct": round(abs(price - poc) / price * 100.0, 2),
        "range_pos_pct": round((price - lo) / (hi - lo) * 100.0, 1),
        "lookback": int(len(df)),
    }


def cvd_divergence(
    df: pd.DataFrame | None,
    lookback: int = CVD_DIVERGENCE_LOOKBACK,
) -> str:
    """Detect price-vs-flow divergence using a cumulative volume delta proxy.

    CVD here is price-derived (up-close days count volume as buy, down-close as
    sell) — the same honest limitation as compute_cvd_efficiency. Returns
    NONE / BULLISH / BEARISH.
    """
    if df is None or len(df) < 30 or "Volume" not in df:
        return "NONE"
    closes = df["Close"].astype(float)
    vols = df["Volume"].astype(float).to_numpy()
    n = len(closes)
    if n <= lookback:
        return "NONE"

    signs = np.sign(closes.diff().fillna(0.0).to_numpy())
    cvd = np.cumsum(signs * vols)
    c_now = float(cvd[-1])
    c_prev = float(cvd[-1 - lookback])
    p_now = float(closes.iloc[-1])
    p_prev = float(closes.iloc[-1 - lookback])

    if p_now > p_prev and c_now < c_prev:
        return "BEARISH"
    if p_now < p_prev and c_now > c_prev:
        return "BULLISH"
    return "NONE"


def futures_basis(
    futures_df: pd.DataFrame | None,
    physical_df: pd.DataFrame | None,
    lookback: int = BASIS_AVG_LOOKBACK,
    baseline: int = BASIS_BASELINE_LOOKBACK,
) -> dict | None:
    """Premium/discount of futures over physical gold, vs its own rolling baseline.

    Yahoo no longer serves a free spot XAUUSD series, so the physical leg is a
    proxy (e.g. GLD ETF). Because the futures/ETF absolute ratio is not a fixed
    number, the signal is expressed RELATIVE to the ratio's own ``baseline``-day
    rolling mean: futures trading rich vs that baseline = PREMIUM, cheap =
    DISKONTO. Returns None when overlapping history is too short.
    """
    if (
        futures_df is None
        or physical_df is None
        or len(futures_df) < 2
        or len(physical_df) < 2
    ):
        return None
    f = futures_df["Close"].astype(float)
    s = physical_df["Close"].astype(float)
    idx = f.index.intersection(s.index)
    if len(idx) < baseline:  # need enough history for the rolling baseline
        return None
    f = f.loc[idx]
    s = s.loc[idx]
    if not (f.iloc[-1] > 0 and s.iloc[-1] > 0):
        return None
    ratio = f / s
    base = ratio.rolling(baseline, min_periods=max(20, baseline // 2)).mean()
    prem = (ratio / base - 1.0) * 100.0
    prem = prem.dropna()
    if prem.empty or not np.isfinite(prem.iloc[-1]):
        return None
    last = float(prem.iloc[-1])
    avg = float(prem.tail(lookback).mean())
    band = BASIS_PREMIUM_BAND_PCT
    state = "PREMIUM" if last > band else "DISKONTO" if last < -band else "NETRAL"
    return {
        "last_pct": round(last, 3),
        "avg20_pct": round(avg, 3),
        "state": state,
        "spot": round(float(s.iloc[-1]), 3),
        "future": round(float(f.iloc[-1]), 3),
        "lookback_days": int(len(idx)),
    }