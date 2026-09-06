import logging
import threading
import time

import pandas as pd

from config import INTERVAL, PERIOD, SYMBOLS

logger = logging.getLogger("data")


class DataService:
    def __init__(self):
        self._cache = {}
        self._lock = threading.Lock()

    def _get(self, key):
        with self._lock:
            entry = self._cache.get(key)
            if entry and entry["expires"] > time.time():
                return entry["df"]
        return None

    def _put(self, key, df, ttl):
        with self._lock:
            self._cache[key] = {"df": df, "expires": time.time() + ttl}

    def fetch(self, symbol: str, ttl: int = 180) -> pd.DataFrame:
        if symbol not in SYMBOLS:
            raise ValueError(f"Unsupported symbol: {symbol}")
        yahoo = SYMBOLS[symbol]["yahoo"]
        cache_key = f"{yahoo}|{PERIOD}|{INTERVAL}"
        cached = self._get(cache_key)
        if cached is not None:
            return cached.copy()
        df = self._download(yahoo)
        if df is None or df.empty:
            logger.warning("yfinance returned empty data, using synthetic fallback")
            df = self._synthetic(symbol)
        df = self._clean(df)
        self._put(cache_key, df, ttl)
        return df.copy()

    def _download(self, yahoo: str) -> pd.DataFrame:
        import time as _time

        last_error = None
        for attempt in range(3):
            try:
                import yfinance as yf

                ticker = yf.Ticker(yahoo)
                df = ticker.history(period=PERIOD, interval=INTERVAL, auto_adjust=False)
                if df is None or df.empty:
                    last_error = ValueError("empty result")
                else:
                    return df
            except Exception as exc:
                last_error = exc
            if attempt < 2:
                _time.sleep(3 + attempt * 2)
        logger.warning("yfinance download failed after 3 attempts: %s", last_error)
        return None

    def _synthetic(self, symbol: str) -> pd.DataFrame:
        import numpy as np

        rng = np.random.default_rng(42)
        n = 140
        base = 4500.0 if symbol == "XAUUSD" else (18500.0 if symbol == "NASDAQ" else 0.66)
        vol = 0.012 if symbol == "XAUUSD" else (0.014 if symbol == "NASDAQ" else 0.006)
        drift = 0.0004
        returns = rng.normal(drift, vol, n)
        closes = base * np.exp(np.cumsum(returns))
        dates = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
        highs = closes * (1 + np.abs(rng.normal(0, vol / 2, n)))
        lows = closes * (1 - np.abs(rng.normal(0, vol / 2, n)))
        opens = np.roll(closes, 1)
        opens[0] = closes[0]
        volumes = rng.integers(1_000_000, 8_000_000, n)
        return pd.DataFrame(
            {"Open": opens, "High": highs, "Low": lows, "Close": closes, "Volume": volumes},
            index=dates,
        )

    def _clean(self, df: pd.DataFrame) -> pd.DataFrame:
        df = df[["Open", "High", "Low", "Close", "Volume"]].dropna()
        df.index = pd.to_datetime(df.index).tz_localize(None)
        df = df.sort_index()
        df["Close"] = df["Close"].astype(float)
        df["Open"] = df["Open"].astype(float)
        df["High"] = df["High"].astype(float)
        df["Low"] = df["Low"].astype(float)
        return df


data_service = DataService()