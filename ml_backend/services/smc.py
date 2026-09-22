"""Smart Money Concepts (SMC) context estimated from daily OHLCV.

These helpers translate the institutional playbook (FVG, order blocks,
liquidity sweeps, premium/discount, BOS/ChoCh) into honest daily proxies.
Everything is estimated from the yfinance series — there is no intraday
M5/tick order flow behind these numbers, and the app says so out loud.
"""
import numpy as np
import pandas as pd

SWING_LOOKBACK = 126
FVG_LOOKBACK = 90
OB_LOOKBACK = 90
PREMIUM_MID_THRESHOLD = 0.55  # >55% premium band, <45% discount band


def _bars(df):
    return {
        "open": df["Open"].astype(float).to_numpy(),
        "high": df["High"].astype(float).to_numpy(),
        "low": df["Low"].astype(float).to_numpy(),
        "close": df["Close"].astype(float).to_numpy(),
    }


def swing_points(df, left: int = 2, right: int = 2) -> dict:
    """Fractal swing highs/lows.

    A swing high at i requires the High to exceed the ``left`` bars before
    and the ``right`` bars after (strictly). Returns series of prices with the
    confirmation index implied by the last confirmed position.
    """
    n = len(df)
    b = _bars(df)
    sh_price = np.full(n, np.nan)
    sl_price = np.full(n, np.nan)
    for i in range(left, n - right):
        seg_high = b["high"][i - left : i + right + 1]
        seg_low = b["low"][i - left : i + right + 1]
        if b["high"][i] == seg_high.max() and np.count_nonzero(seg_high >= b["high"][i]) == 1:
            sh_price[i] = b["high"][i]
        if b["low"][i] == seg_low.min() and np.count_nonzero(seg_low <= b["low"][i]) == 1:
            sl_price[i] = b["low"][i]
    # only report swings fully confirmed (right bars exist before today)
    last_confirmed = n - 1 - right
    sh = [(i, sh_price[i]) for i in range(n) if i <= last_confirmed and np.isfinite(sh_price[i])]
    sl = [(i, sl_price[i]) for i in range(n) if i <= last_confirmed and np.isfinite(sl_price[i])]
    return {"highs": sh, "lows": sl, "n": n}


def _trend_from_swings(sh: list, sl: list) -> str:
    if len(sh) >= 2 and len(sl) >= 2:
        hh = sh[-1][1] >= sh[-2][1]
        hl = sl[-1][1] >= sl[-2][1]
        if hh and hl:
            return "BULLISH"
        if not hh and not hl:
            return "BEARISH"
    if len(sh) >= 1 and len(sl) >= 1:
        return "BULLISH" if sh[-1][1] >= sl[-1][1] else "BEARISH"
    return "NEUTRAL"


def structure(df) -> dict:
    """Last confirmed swings + trend + breakout (BOS vs ChoCh) attempt."""
    sw = swing_points(df)
    n = sw["n"]
    closes = _bars(df)["close"]
    last_close = float(closes[-1])
    trend = _trend_from_swings(sw["highs"], sw["lows"])
    sh = sw["highs"][-1] if sw["highs"] else None
    sl = sw["lows"][-1] if sw["lows"] else None

    breakout = None
    breakout_type = None
    retrace = None
    if sh is not None and last_close > sh[1]:
        prev_high = sw["highs"][-2][1] if len(sw["highs"]) >= 2 else sh[1]
        breakout = "BULLISH"
        breakout_type = "BOS" if trend == "BULLISH" else "CHOCH"
        retrace = round((sh[1] + prev_high) / 2, 5)
    elif sl is not None and last_close < sl[1]:
        prev_low = sw["lows"][-2][1] if len(sw["lows"]) >= 2 else sl[1]
        breakout = "BEARISH"
        breakout_type = "BOS" if trend == "BEARISH" else "CHOCH"
        retrace = round((sl[1] + prev_low) / 2, 5)

    return {
        "trend": trend,
        "swing_high": round(sh[1], 5) if sh else None,
        "swing_high_bars_ago": n - 1 - sh[0] if sh else None,
        "swing_low": round(sl[1], 5) if sl else None,
        "swing_low_bars_ago": n - 1 - sl[0] if sl else None,
        "breakout": breakout,
        "breakout_type": breakout_type,
        "retracement_level": retrace,
    }


def fvg(df, lookback: int = FVG_LOOKBACK) -> dict:
    """Most recent unmitigated Fair Value Gap per side.

    Bullish FVG: Low[i] > High[i-2]; zone [High[i-2], Low[i]].
    Bearish FVG: High[i] < Low[i-2]; zone [High[i], Low[i-2]].
    Unmitigated = no later bar traded back into the zone.
    """
    if len(df) < 20:
        return {"bullish": None, "bearish": None}
    d = df.tail(lookback)
    b = _bars(d)
    n = len(d)
    last_date = df.index[-1]

    def zone_date(idx: int):
        return int((last_date - d.index[idx]).days)

    bull = None
    bear = None
    for i in range(2, n):
        if b["low"][i] > b["high"][i - 2]:
            top = float(b["low"][i])
            bottom = float(b["high"][i - 2])
            later_lows = b["low"][i + 1 :]
            if later_lows.size and later_lows.min() > top:
                bull = {"top": round(top, 5), "bottom": round(bottom, 5), "age_days": zone_date(i)}
        if b["high"][i] < b["low"][i - 2]:
            top = float(b["low"][i - 2])
            bottom = float(b["high"][i])
            later_highs = b["high"][i + 1 :]
            if later_highs.size and later_highs.max() < bottom:
                bear = {"top": round(top, 5), "bottom": round(bottom, 5), "age_days": zone_date(i)}
    return {"bullish": bull, "bearish": bear}


def order_blocks(df, lookback: int = OB_LOOKBACK) -> dict:
    """Order block = last opposite candle before the candles that opened the FVG."""
    if len(df) < 20:
        return {"bullish": None, "bearish": None}
    d = df.tail(lookback)
    b = _bars(d)
    n = len(d)
    last_date = df.index[-1]

    def zone_date(idx: int):
        return int((last_date - d.index[idx]).days)

    bull_ob = None
    bear_ob = None
    for i in range(2, n):
        if b["low"][i] > b["high"][i - 2]:
            for j in range(i - 1, max(-1, i - 8), -1):
                if b["close"][j] < b["open"][j]:
                    bull_ob = {
                        "top": round(float(b["high"][j]), 5),
                        "bottom": round(float(b["low"][j]), 5),
                        "age_days": zone_date(j),
                    }
                    break
        if b["high"][i] < b["low"][i - 2]:
            for j in range(i - 1, max(-1, i - 8), -1):
                if b["close"][j] > b["open"][j]:
                    bear_ob = {
                        "top": round(float(b["high"][j]), 5),
                        "bottom": round(float(b["low"][j]), 5),
                        "age_days": zone_date(j),
                    }
                    break
    return {"bullish": bull_ob, "bearish": bear_ob}


def liquidity(df) -> dict:
    """PDH/PDL levels + sweep detection on the last bar (daily proxy)."""
    if len(df) < 2:
        return {"pdh": None, "pdl": None, "sweep": "NONE", "sweep_type": None}
    prev = df.iloc[-2]
    cur = df.iloc[-1]
    pdh = float(prev["High"])
    pdl = float(prev["Low"])
    high_now = float(cur["High"])
    low_now = float(cur["Low"])
    close_now = float(cur["Close"])

    sweep_types = []
    if high_now > pdh and close_now < pdh:
        sweep_types.append("SELL_SWEEP")
    if low_now < pdl and close_now > pdl:
        sweep_types.append("BUY_SWEEP")
    if not sweep_types:
        sweep = "NONE"
        stype = None
    elif len(sweep_types) == 1:
        sweep = sweep_types[0]
        stype = sweep_types[0]
    else:
        sweep = "BOTH"
        stype = "BOTH"

    return {
        "pdh": round(pdh, 5),
        "pdl": round(pdl, 5),
        "sweep": sweep,
        "sweep_type": stype,
    }


def premium_discount(df) -> dict:
    """Where price sits inside the last swing range vs its midpoint."""
    sw = swing_points(df)
    n = sw["n"]
    sh = sw["highs"][-1] if sw["highs"] else None
    sl = sw["lows"][-1] if sw["lows"] else None
    last_close = float(df["Close"].iloc[-1])
    if sh is None or sl is None or sh[1] <= sl[1]:
        return {"equilibrium": None, "pos": "NETRAL", "pct": None}
    eq = (sh[1] + sl[1]) / 2.0
    span = sh[1] - sl[1]
    pct = (last_close - sl[1]) / span * 100.0 if span > 0 else 50.0
    if pct > PREMIUM_MID_THRESHOLD * 100:
        pos = "PREMIUM"
    elif pct < (1 - PREMIUM_MID_THRESHOLD) * 100:
        pos = "DISKONTO"
    else:
        pos = "NETRAL"
    return {
        "equilibrium": round(eq, 5),
        "pct": round(float(pct), 1),
        "pos": pos,
    }


def smc_context(df: pd.DataFrame | None) -> dict | None:
    """Full SMC context block for the API payload. Returns None when data is thin."""
    if df is None or len(df) < 30:
        return None
    d = df.tail(SWING_LOOKBACK)

    struct = structure(d)
    fvgs = fvg(d)
    obs = order_blocks(d)
    lid = liquidity(d)
    pd = premium_discount(d)

    # Composite institutional bias from the daily proxies.
    score = 0
    if struct["trend"] == "BULLISH":
        score += 1
    elif struct["trend"] == "BEARISH":
        score -= 1
    if fvgs["bullish"]:
        score += 1
    if fvgs["bearish"]:
        score -= 1
    if pd["pos"] == "DISKONTO":
        score += 1
    elif pd["pos"] == "PREMIUM":
        score -= 1
    if lid["sweep_type"] == "BUY_SWEEP":
        score += 1
    elif lid["sweep_type"] == "SELL_SWEEP":
        score -= 1
    if score >= 2:
        bias = "LEAN_BULLISH"
    elif score <= -2:
        bias = "LEAN_BEARISH"
    else:
        bias = "NETRAL"

    return {
        "available": True,
        "structure": struct,
        "fvg": fvgs,
        "order_blocks": obs,
        "liquidity": lid,
        "premium_discount": pd,
        "bias": bias,
        "note": (
            "Estimasi Smart Money dari data HARIAN (GC=F), bukan order-flow intraday. "
            "FVG/OB/sweep ialah proksi harga, bukan konfirmasi M5."
        ),
    }