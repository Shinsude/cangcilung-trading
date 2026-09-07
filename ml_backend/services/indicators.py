import numpy as np
import pandas as pd

from config import (
    EMA_FAST,
    EMA_MEDIUM,
    EMA_SLOW,
    MACD_FAST,
    MACD_SIGNAL,
    MACD_SLOW,
    MIDDLE_BAND,
    RSI_PERIOD,
)


def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def sma(series: pd.Series, period: int) -> pd.Series:
    return series.rolling(window=period).mean()


def rsi(series: pd.Series, period: int = RSI_PERIOD) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0).ewm(alpha=1 / period, adjust=False).mean()
    loss = (-delta.clip(upper=0)).ewm(alpha=1 / period, adjust=False).mean()
    rs = gain / loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def macd(series: pd.Series):
    line = ema(series, MACD_FAST) - ema(series, MACD_SLOW)
    signal = line.ewm(span=MACD_SIGNAL, adjust=False).mean()
    hist = line - signal
    return line, signal, hist


def bollinger(series: pd.Series, period: int = MIDDLE_BAND, width: float = 2.0):
    mid = sma(series, period)
    std = series.rolling(window=period).std()
    upper = mid + width * std
    lower = mid - width * std
    return upper, mid, lower


def compute_all(df: pd.DataFrame) -> dict:
    close = df["Close"]
    r = rsi(close)
    macd_line, macd_signal, macd_hist = macd(close)
    ema_f = ema(close, EMA_FAST)
    ema_m = ema(close, EMA_MEDIUM)
    ema_s = ema(close, EMA_SLOW)
    bb_upper, bb_mid, bb_lower = bollinger(close)
    sma_20 = sma(close, MIDDLE_BAND)

    last = len(close) - 1
    if last < 0:
        raise ValueError("Empty data")

    rsi_now = float(r.iloc[last]) if np.isfinite(r.iloc[last]) else 50.0
    mac_val = float(macd_line.iloc[last])
    mac_sig = float(macd_signal.iloc[last])
    mac_hist = float(macd_hist.iloc[last])
    prev_hist = (
        float(macd_hist.iloc[last - 1]) if last > 1 and np.isfinite(macd_hist.iloc[last - 1]) else 0.0
    )
    cross = None
    if np.isfinite(prev_hist):
        if prev_hist <= 0 < mac_hist:
            cross = "bullish"
        elif prev_hist >= 0 > mac_hist:
            cross = "bearish"
        else:
            cross = "bullish" if mac_hist > 0 else "bearish"

    price = float(close.iloc[last])
    bb_range = bb_upper.iloc[last] - bb_lower.iloc[last]
    percent_b = None
    if np.isfinite(bb_range) and bb_range != 0:
        percent_b = float((price - bb_lower.iloc[last]) / bb_range)

    # Konfirmasi volume: arah & kekuatan hari ini relatif rata-rata 20 hari (z-score bounded)
    vol_conf = 0.0
    if len(df) >= 20 and "Volume" in df:
        vol_tail = df["Volume"].tail(20).astype(float)
        vmean = float(vol_tail[:-1].mean())
        vstd = float(vol_tail[:-1].std())
        vnow = float(vol_tail.iloc[-1])
        direction = 1.0 if (len(close) > 1 and price > float(close.iloc[-2])) else -1.0
        if vmean > 0 and vstd > 0:
            z = (vnow - vmean) / vstd
            z_clamped = max(-1.0, min(1.0, z / 2.0))
            vol_conf = 0.5 * direction + 0.5 * z_clamped

    # Posisi harga terhadap range 20 hari (support/resistance)
    sr_pos = 0.5
    if len(close) >= 20:
        hi20 = float(np.nanmax(df["High"].tail(20).to_numpy()))
        lo20 = float(np.nanmin(df["Low"].tail(20).to_numpy()))
        if hi20 != lo20:
            sr_pos = (price - lo20) / (hi20 - lo20)

    return {
        "price": price,
        "rsi": {"value": round(rsi_now, 2), "region": "oversold" if rsi_now < 30 else ("overbought" if rsi_now > 70 else "neutral")},
        "macd": {
            "value": round(mac_val, 5),
            "signal": round(mac_sig, 5),
            "histogram": round(mac_hist, 5),
            "cross": cross,
        },
        "ema": {
            "ema9": round(float(ema_f.iloc[last]), 5),
            "ema21": round(float(ema_m.iloc[last]), 5),
            "ema50": round(float(ema_s.iloc[last]), 5),
            "trend": "bullish" if price > float(ema_m.iloc[last]) else "bearish",
        },
        "bollinger": {
            "upper": round(float(bb_upper.iloc[last]), 5),
            "middle": round(float(bb_mid.iloc[last]), 5),
            "lower": round(float(bb_lower.iloc[last]), 5),
            "percent_b": round(percent_b, 3) if percent_b is not None else None,
        },
        "sma20": round(float(sma_20.iloc[last]), 5),
        "volatility_20": round(float(close.tail(20).pct_change().std() or 0.0), 5),
        "volume": round(vol_conf, 3),
        "sr": round(sr_pos, 3),
    }