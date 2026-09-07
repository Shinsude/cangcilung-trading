"""Konfirmasi tren multi-timeframe (1h & 4h) untuk sinyal.

Alignment ini adalah lapisan konfirmasi FIXED (bobot kecil, tidak di-tune agar tidak
mengubah grid pencarian backtest harian). Jika data timeframe kecil tidak tersedia,
alignment jatuh ke 0 dan sinyal tetap murni dari kerangka harian.
"""
import numpy as np
import pandas as pd

from services.indicators import ema

TF_WEIGHT = 0.6


def _ratio(df: pd.DataFrame) -> float:
    if df is None or len(df) < 30:
        return 0.0
    closes = df["Close"].astype(float)
    price = float(closes.iloc[-1])
    last_f = float(ema(closes, 12).iloc[-1])
    last_s = float(ema(closes, 26).iloc[-1])
    v = 0.0
    if price > last_f > last_s:
        v += 0.5
    elif price < last_f < last_s:
        v -= 0.5
    if len(closes) >= 14:
        base = float(closes.iloc[-14])
        if base > 0:
            slope = price / base - 1.0
            v += float(np.clip(slope * 25.0, -0.5, 0.5))
    return float(np.clip(v, -1.0, 1.0))


def alignment(df_1h: pd.DataFrame | None, df_4h: pd.DataFrame | None) -> tuple[float, dict]:
    parts: dict[str, float] = {}
    if df_1h is not None and len(df_1h) > 30:
        parts["1h"] = round(_ratio(df_1h), 3)
    if df_4h is not None and len(df_4h) > 40:
        parts["4h"] = round(_ratio(df_4h), 3)
    if not parts:
        return 0.0, parts
    value = float(np.clip(sum(parts.values()) / len(parts), -1.0, 1.0))
    return round(value, 3), parts