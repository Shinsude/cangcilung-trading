import os

SYMBOLS = {
    "XAUUSD": {
        "yahoo": "GC=F",
        "name": "Gold Spot",
        "decimals": 2,
        "category": "Commodity",
    },
}

PERIOD = os.getenv("DATA_PERIOD", "1y")
INTERVAL = os.getenv("DATA_INTERVAL", "1d")
LOOKBACK_WINDOWS = [12, 24, 36]
GRU_EPOCHS = 180
MIDDLE_BAND = 20
RSI_PERIOD = 14
MACD_FAST = 12
MACD_SLOW = 26
MACD_SIGNAL = 9
EMA_FAST = 9
EMA_MEDIUM = 21
EMA_SLOW = 50
ATR_PERIOD = 14

FINNHUB_API_KEY = os.getenv("FINNHUB_API_KEY", "")
NEWS_LIMIT = 5

CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "900"))
TUNE_TTL_SECONDS = int(os.getenv("TUNE_TTL_SECONDS", "21600"))

MT5_TERMINAL_PATH = os.getenv("MT5_TERMINAL_PATH", r"C:\Program Files\HFM Metatrader 5\terminal64.exe")
MT5_SYMBOL = os.getenv("MT5_SYMBOL", "XAUUSD")
MT5_TIMEFRAME = os.getenv("MT5_TIMEFRAME", "M30")
MT5_LOGIN = os.getenv("MT5_LOGIN", "")
MT5_PASSWORD = os.getenv("MT5_PASSWORD", "")
MT5_SERVER = os.getenv("MT5_SERVER", "")