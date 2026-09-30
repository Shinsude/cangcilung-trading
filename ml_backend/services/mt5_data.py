"""Konektor data historis via MetaTrader 5 (terminal lokal HFM/Markets).

Memberi akses ke M1/M5/M15/M30 — timeframe yang tidak bisa didapat panjang
dari yfinance gratis (hanya ~60 hari). Dipakai riset (probe/backtest/forward),
BUKAN bagian jalur sinyal live. Semua fungsi menurunkan diri (None / dict
status) saat terminal tidak tersedia — tidak pernah raise yang membocorkan
path/data.
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

import pandas as pd

from config import (
    MT5_LOGIN,
    MT5_PASSWORD,
    MT5_SERVER,
    MT5_SYMBOL,
    MT5_TERMINAL_PATH,
    MT5_TIMEFRAME,
)

logger = logging.getLogger(__name__)

TF_MAP = {
    "M1": "TIMEFRAME_M1",
    "M5": "TIMEFRAME_M5",
    "M15": "TIMEFRAME_M15",
    "M30": "TIMEFRAME_M30",
    "H1": "TIMEFRAME_H1",
    "H4": "TIMEFRAME_H4",
    "D1": "TIMEFRAME_D1",
    "W1": "TIMEFRAME_W1",
}

COLUMNS = ["Open", "High", "Low", "Close", "Volume"]


def discover_terminal() -> str | None:
    """Cari terminal64.exe: env/variabel config, lalu beberapa path umum."""
    candidates = [
        MT5_TERMINAL_PATH,
        r"C:\Program Files\MetaTrader 5\terminal64.exe",
        r"C:\Program Files\MetaTrader 5\terminal.exe",
        r"C:\Program Files (x86)\MetaTrader 5\terminal64.exe",
        r"C:\Program Files\HFM Metatrader 5\terminal64.exe",
        r"D:\MetaTrader 5\terminal64.exe",
    ]
    for p in candidates:
        if p and Path(p).is_file():
            return p
    for base in (r"C:\Program Files", r"C:\Program Files (x86)", r"D:\\"):
        if not Path(base).is_dir():
            continue
        for sub in Path(base).iterdir():
            if sub.name.lower().find("metatrader") == -1 and sub.name.lower().find("terminal") == -1:
                continue
            exe = sub / "terminal64.exe"
            if exe.is_file():
                return str(exe)
    return None


def _session(terminal: str | None = None):
    import time

    try:
        import MetaTrader5 as mt5
    except ImportError:
        return None, "MetaTrader5 tidak terpasang"

    path = terminal or discover_terminal()
    if path is None or not Path(path).is_file():
        return None, "terminal64.exe tidak ditemukan"
    if not mt5.initialize(path):
        return None, f"mt5.initialize gagal (rc={mt5.last_error()})"
    time.sleep(1)  # biarkan terminal settle, hindari "Invalid params" sesaat
    if MT5_LOGIN and MT5_PASSWORD:
        ok = mt5.login(MT5_LOGIN, password=MT5_PASSWORD, server=MT5_SERVER or None)
        if not ok:
            account = mt5.account_info()
            if account is None:
                mt5.shutdown()
                return None, f"login gagal (rc={mt5.last_error()})"
    return mt5, None


def terminal_status(terminal: str | None = None) -> dict:
    """Status ringkas untuk laporan/UI: path, akun, simbol tersedia."""
    mt5, err = _session(terminal)
    if mt5 is None:
        return {"ok": False, "error": err, "path": discover_terminal()}
    try:
        info = mt5.account_info()
        account = {"login": info.login, "server": info.server} if info else None
        symbol = mt5.symbol_info(MT5_SYMBOL)
        return {
            "ok": True,
            "path": discover_terminal(),
            "account": account,
            "symbol_available": bool(symbol is not None),
        }
    finally:
        mt5.shutdown()


def _clean_mt5(df: pd.DataFrame) -> pd.DataFrame:
    if "time" not in df.columns:
        return pd.DataFrame()
    df["time"] = pd.to_datetime(df["time"], unit="s")
    df = df.set_index("time")
    df.index.name = None
    rename = {
        "open": "Open", "high": "High", "low": "Low", "close": "Close",
        "tick_volume": "Volume", "real_volume": "Volume",
    }
    df = df.rename(columns={k: v for k, v in rename.items() if k in df.columns})
    if df.columns.duplicated().any():
        df = df.loc[:, ~df.columns.duplicated()]
    if not set(COLUMNS) <= set(df.columns):
        return pd.DataFrame()
    df = df[COLUMNS].dropna()
    df.index = pd.to_datetime(df.index).tz_localize(None)
    df = df.sort_index()
    for c in COLUMNS:
        df[c] = df[c].astype(float)
    return df


def fetch_mt5(symbol: str = MT5_SYMBOL, timeframe: str = MT5_TIMEFRAME,
              start=None, end=None, terminal: str | None = None) -> pd.DataFrame | None:
    """Ambil OHLCV historis dari terminal MT5 lokal.

    ``start/end`` menerima string/``datetime``; kosong = sebanyak yang terminal
    sediakan. Timeframe masuk akal: M1/M5/M15/M30/H1/H4/D1/W1.

    Validasi timeframe dilakukan sebelum import ``MetaTrader5`` supaya fungsi
    menurunkan diri (None) bahkan tanpa paket terpasang (Linux/CI).
    """
    key = TF_MAP.get(str(timeframe).upper())
    if key is None:
        logger.warning("timeframe tidak dikenal: %s", timeframe)
        return None
    try:
        import MetaTrader5 as mt5
    except ImportError:
        logger.warning("MetaTrader5 tidak terpasang")
        return None

    mt5_session, err = _session(terminal)
    if mt5_session is None:
        logger.warning("MT5 tidak tersedia: %s", err)
        return None
    try:
        if not mt5_session.symbol_select(symbol, True):
            logger.warning("MT5 symbol_select gagal untuk %s (rc=%s)", symbol, mt5_session.last_error())
            return None
        dt_to = pd.Timestamp(end) if end is not None else pd.Timestamp.now()
        if start is not None:
            starts = [pd.Timestamp(start)]
        else:
            starts = [pd.Timestamp(x) for x in
                      ("2015-01-01", "2023-01-01", "2024-01-01", "2025-01-01",
                       "2026-01-01", "2026-08-01")]
        rates = None
        for s in starts:
            rates = mt5_session.copy_rates_range(symbol, getattr(mt5_session, key), s, dt_to)
            if rates is not None and len(rates) > 0:
                break
        if rates is None or len(rates) == 0:
            logger.warning("MT5 kosong untuk %s %s", symbol, timeframe)
            return None
        clean = _clean_mt5(pd.DataFrame(rates))
        if clean is None or clean.empty:
            logger.warning("MT5 bersih kosong untuk %s %s", symbol, timeframe)
            return None
        return clean
    except Exception as exc:  # noqa: BLE001
        logger.warning("fetch_mt5 gagal: %s", exc)
        return None
    finally:
        mt5_session.shutdown()


def mt5_available() -> bool:
    try:
        import MetaTrader5  # noqa: F401
    except ImportError:
        return False
    return discover_terminal() is not None


def save_csv(df: pd.DataFrame, path: str) -> None:
    parent = os.path.dirname(path)
    if parent:
        Path(parent).mkdir(parents=True, exist_ok=True)
    df.to_csv(path, date_format="%Y-%m-%d %H:%M:%S")