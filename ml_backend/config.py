import os

SYMBOLS = {
    "XAUUSD": {
        "yahoo": "GC=F",
        "name": "Gold Spot",
        "decimals": 2,
        "category": "Commodity",
    },
    "NASDAQ": {
        "yahoo": "^IXIC",
        "name": "Nasdaq Composite",
        "decimals": 2,
        "category": "Index",
    },
    "AUDUSD": {
        "yahoo": "AUDUSD=X",
        "name": "AUD / USD",
        "decimals": 5,
        "category": "Forex",
    },
    "EURUSD": {
        "yahoo": "EURUSD=X",
        "name": "EUR / USD",
        "decimals": 5,
        "category": "Forex",
    },
    "GBPUSD": {
        "yahoo": "GBPUSD=X",
        "name": "GBP / USD",
        "decimals": 5,
        "category": "Forex",
    },
    "BTCUSD": {
        "yahoo": "BTC-USD",
        "name": "Bitcoin / USD",
        "decimals": 2,
        "category": "Crypto",
    },
    "DXY": {
        "yahoo": "DX-Y.NYB",
        "name": "US Dollar Index",
        "decimals": 2,
        "category": "Index",
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

CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "180"))
TUNE_TTL_SECONDS = int(os.getenv("TUNE_TTL_SECONDS", "21600"))