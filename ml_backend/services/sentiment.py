import logging
import math
from datetime import datetime, timedelta

import requests

from config import FINNHUB_API_KEY, NEWS_LIMIT, SYMBOLS

logger = logging.getLogger("sentiment")

BULLISH = {
    "rally", "surge", "surges", "gain", "gains", "up", "higher", "high",
    "breakout", "break", "beat", "beats", "strong", "growth", "grow",
    "upgrade", "optimistic", "buy", "bullish", "jump", "soar", "soars",
    "record", "boost", "inflation eases", "rate cut", "dovish", "recovery",
    "expansion", "profit", "exceed", "support",
}
BEARISH = {
    "drop", "drops", "fall", "falls", "plunge", "plunges", "crash", "down",
    "lower", "weak", "downgrade", "miss", "misses", "selloff", "bearish",
    "sell", "recession", "cut forecast", "loss", "loses", "slump", "slumps",
    "disappoint", "hawkish", "rate hike", "uncertainty", "fear", "risk-off",
    "decline", "declines", "turmoil", "pressure", "shakeout", "retreat",
}

KEYWORDS = {
    "XAUUSD": ["gold", "xau", "precious metal", "bullion", "fed", "dollar", "usd"],
    "NASDAQ": ["nasdaq", "tech", "technology", "nvidia", "apple", "microsoft",
               "semiconductor", "ai", "fed", "earnings", "big tech"],
    "AUDUSD": ["aud", "australia", "rba", "dollar", "usd", "reserve bank australia",
               "miners", "china"],
}


def _score_text(text: str) -> float:
    low = text.lower()
    for kw in KEYWORDS.get("__ALL__", []):
        if kw not in low:
            return 0.0
    pos = sum(1 for w in BULLISH if w in low)
    neg = sum(1 for w in BEARISH if w in low)
    total = pos + neg
    if total == 0:
        return 0.0
    return (pos - neg) / total


def _finnhub_news(symbol: str) -> list:
    yahoo = SYMBOLS[symbol]["yahoo"]
    query = "gold" if symbol == "XAUUSD" else ("nasdaq" if symbol == "NASDAQ" else "audusd")
    if not FINNHUB_API_KEY:
        return []
    url = "https://finnhub.io/api/v1/company-news"
    params = {
        "symbol": query,
        "from": (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d"),
        "to": datetime.utcnow().strftime("%Y-%m-%d"),
        "token": FINNHUB_API_KEY,
    }
    try:
        resp = requests.get(url, params=params, timeout=10)
        if resp.status_code == 200:
            items = resp.json()[:NEWS_LIMIT]
            out = []
            for it in items:
                headline = (it.get("headline") or "").strip()
                if headline:
                    out.append({"source": "finnhub", "headline": headline,
                                "url": it.get("url", ""), "time": it.get("datetime")})
            return out
    except Exception as exc:
        logger.warning("finnhub news failed: %s", exc)
    return []


def analyze(symbol, price_momentum: float) -> dict:
    headlines = _finnhub_news(symbol)
    if headlines:
        scores = [math.tanh(_score_text(h["headline"]) * 3) for h in headlines]
        score = float(sum(scores) / len(scores))
        label = "BULLISH" if score > 0.15 else ("BEARISH" if score < -0.15 else "NEUTRAL")
        return {
            "score": round(score, 3),
            "label": label,
            "source": "finnhub",
            "headlines": headlines,
        }

    momentum_label = "BULLISH" if price_momentum > 0.02 else ("BEARISH" if price_momentum < -0.02 else "NEUTRAL")
    momentum_score = max(-1.0, min(1.0, price_momentum * 12))
    return {
        "score": round(momentum_score, 3),
        "label": momentum_label,
        "source": "price-momentum-estimate",
        "headlines": [],
    }