"""Intraday research pipeline (probe, bukan signal live).

yfinance membatasi bar intraday: 5m/15m/30m hanya ~60 hari terakhir; 60m/1h
sampai ~730 hari. Jadi verifikasi "limit entry di zona" pada timeframe yang
benar (bukan daily) dibagi dua jalur:

- jalur A: 60m, 2 tahun -> bisa split IS/OOS yang jujur (bukan 1 bar/hari).
- jalur B: 30m, 60 hari -> granularity asli M30, sampel kecil (saat ini).

Keduanya memakai mesin yang sama: ``backtest_limit_entries``. Hasil dicatat di
research/baseline_falsification.md, bukan diklaim sebagai alpha.
"""
from __future__ import annotations

import pandas as pd

from services.smc_limit_backtester import backtest_limit_entries

# Parameter skala intraday (jam): zona segar ~6 jam, SL dilihat 8 jam ke
# belakang, retest sampai ~24 jam ke depan. Parameter tetap SAMA untuk semua
# slice (bukan di-tune per periode) demi menghindari curve-fit.
INTRADAY_PARAMS = {
    "swing_p": 3,
    "zone_age_bars": 6,
    "sl_bars": 8,
    "retest_lookahead": 24,
    "rr": 2.0,
}

COLUMNS = ["Open", "High", "Low", "Close", "Volume"]


def fetch_intraday(interval: str = "60m", period: str = "2y") -> pd.DataFrame | None:
    """Fetak OHLCV intraday GC=F via yfinance, tz di-drop (konsisten dengan pipeline)."""
    import yfinance as yf

    df = yf.download("GC=F", period=period, interval=interval, progress=False, auto_adjust=False)
    if df is None or df.empty:
        return None
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    df = df[COLUMNS].dropna()
    df.index = pd.to_datetime(df.index).tz_localize(None)
    df = df.sort_index()
    for c in COLUMNS:
        df[c] = df[c].astype(float)
    return df


def run_intraday(interval: str = "60m", period: str = "2y",
                 is_start=None, is_end=None, oos_start=None, oos_end=None,
                 params: dict | None = None) -> dict:
    """Jalankan limit backtester pada data intraday dengan parameter skala jam.

    ``is_./oos_`` diisi string tanggal ISO (naive). Jika semua kosong, mesin
    memakai split 60/40 default (berguna untuk 60m 2 tahun).
    """
    df = fetch_intraday(interval=interval, period=period)
    if df is None or df.empty:
        return {"note": "no intraday data", "bars": 0}
    p = dict(INTRADAY_PARAMS, **(params or {}))
    kw = {k: v for k, v in p.items() if k != "rr"}
    res = backtest_limit_entries(
        df,
        is_start=is_start, is_end=is_end,
        oos_start=oos_start, oos_end=oos_end,
        rr=p["rr"], **kw,
    )
    res["interval"] = interval
    res["range"] = [str(df.index[0]), str(df.index[-1])]
    return res


def probe() -> dict:
    """Probe standar: jalur A (60m 2y, split IS/OOS) + jalur B (30m 60d)."""
    out = {}
    a = run_intraday(interval="60m", period="2y",
                     is_start=None, is_end=None, oos_start=None, oos_end=None)
    out["60m_2y"] = a
    b = run_intraday(interval="30m", period="60d")
    out["30m_60d"] = b
    return out


if __name__ == "__main__":
    import json

    print(json.dumps(probe(), indent=1, default=str))