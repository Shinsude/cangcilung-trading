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