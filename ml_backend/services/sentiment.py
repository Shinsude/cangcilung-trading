import logging
import math
from datetime import datetime, timedelta

import requests

from config import FINNHUB_API_KEY, NEWS_LIMIT, SYMBOLS

logger = logging.getLogger("sentiment")

ACTUALLY_FREE_API = "https://actually-free-api.vercel.app/api/news"

BULLISH = {
    "rally", "surge", "surges", "gain", "gains", "up", "higher", "high",
    "breakout", "break", "beat", "beats", "strong", "growth", "grow",
    "upgrade", "optimistic", "buy", "bullish", "jump", "soar", "soars",
    "record", "boost", "inflation eases", "rate cut", "dovish", "recovery",
    "expansion", "profit", "exceed", "support", "recover", "rebound",
    "lifts", "gain", "climb", "climbs",
}
BEARISH = {
    "drop", "drops", "fall", "falls", "plunge", "plunges", "crash", "down",
    "lower", "weak", "downgrade", "miss", "misses", "selloff", "bearish",
    "sell", "recession", "cut forecast", "loss", "loses", "slump", "slumps",
    "disappoint", "hawkish", "rate hike", "uncertainty", "fear", "risk-off",
    "decline", "declines", "turmoil", "pressure", "shakeout", "retreat",
    "slump", "slip", "slips", "tumble", "plunge", "caution",
}

# Kata dengan dampak kuat terhadap harga (bobot ganda)
STRONG_BULL = {"rally", "surge", "surges", "soar", "soars", "breakout", "record"}
STRONG_BEAR = {"plunge", "plunges", "crash", "selloff", "recession", "tumble", "fear"} | {
    "decline", "declines", "turmoil", "slump", "slumps", "collapse"
}

# Kata pembalik sentimen bila mendahului istilah positif/negatif
NEGATORS = {"not", "no", "slows", "fails to beat", "loses momentum left", "downs", "lack of", "below expectations", "misses"}

KEYWORDS = {
    "XAUUSD": ["gold", "xau", "precious metal", "bullion", "fed", "dollar", "usd"],
    "NASDAQ": ["nasdaq", "tech", "technology", "nvidia", "apple", "microsoft",
               "semiconductor", "ai", "fed", "earnings", "big tech"],
    "AUDUSD": ["aud", "australia", "rba", "dollar", "usd", "reserve bank australia",
               "miners", "china"],
}

# Query pencarian gratis (tanpa kunci) per simbol di ActuallyFreeAPI
SEARCH_QUERIES = {
    "XAUUSD": "gold",
    "NASDAQ": "nasdaq",
    "AUDUSD": "usd",
}


def _score_text(text: str, with_confidence: bool = False):
    low = text.lower()
    pos = 0.0
    neg = 0.0
    hits = 0
    for w in BULLISH:
        if w in low:
            pos += 2.0 if w in STRONG_BULL else 1.0
            hits += 1
    for w in BEARISH:
        if w in low:
            neg += 2.0 if w in STRONG_BEAR else 1.0
            hits += 1

    # Negasi sederhana: cek sebelum istilah pertama yang cocok
    for w in NEGATORS:
        j = low.find(w)
        if j != -1:
            snippet = low[max(0, j): min(len(low), j + len(w) + 60)]
            over = sum(1 for bw in BULLISH if bw in snippet)
            under = sum(1 for bw in BEARISH if bw in snippet)
            if under and not over:
                neg = min(neg * 0.5, 0.5)  # "no crash" -> sentimen membaik
                pos += 0.5
            elif over and not under:
                pos = min(pos * 0.5, 0.5)
                neg += 0.5

    total = pos + neg
    if total == 0:
        return (0.0, 0.0) if with_confidence else 0.0
    raw = (pos - neg) / total
    if not with_confidence:
        return raw
    confidence = min(1.0, 0.35 + hits * 0.13 + abs(raw) * 0.4)
    return round(raw, 3), round(confidence, 3)


def _finnhub_news(symbol: str) -> list:
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


def _actually_free_news(symbol: str) -> list:
    """Berita gratis tanpa API key dari ActuallyFreeAPI."""
    query = SEARCH_QUERIES.get(symbol)
    if not query:
        return []
    try:
        resp = requests.get(
            ACTUALLY_FREE_API,
            params={"search": query, "limit": NEWS_LIMIT, "sort": "pub_date", "order": "desc"},
            timeout=12,
        )
        if resp.status_code != 200:
            return []
        data = resp.json().get("data") or []
        out = []
        for it in data:
            title = (it.get("title") or "").strip()
            if title:
                out.append({
                    "source": (it.get("source") or "news").lower(),
                    "headline": title,
                    "url": it.get("link", ""),
                    "time": it.get("pub_date", ""),
                })
        return out[:NEWS_LIMIT]
    except Exception as exc:
        logger.warning("actually-free news failed: %s", exc)
        return []


def analyze(symbol, price_momentum: float) -> dict:
    # Prioritas: ActuallyFreeAPI (gratis) -> Finnhub (jika key) -> momentum
    headlines = _actually_free_news(symbol) or _finnhub_news(symbol)
    if headlines:
        scored = []
        for h in headlines:
            raw, conf = _score_text(h["headline"], with_confidence=True)
            scored.append({"raw": raw, "conf": conf})
        score = float(sum(math.tanh(s["raw"] * 3.0) * s["conf"] for s in scored) / len(scored))
        avg_conf = float(sum(s["conf"] for s in scored) / len(scored))
        label = "BULLISH" if score > 0.12 else ("BEARISH" if score < -0.12 else "NEUTRAL")
        return {
            "score": round(score, 3),
            "confidence": round(avg_conf, 3),
            "label": label,
            "source": headlines[0]["source"],
            "headlines": headlines,
        }

    momentum_label = "BULLISH" if price_momentum > 0.02 else ("BEARISH" if price_momentum < -0.02 else "NEUTRAL")
    momentum_score = max(-1.0, min(1.0, price_momentum * 12))
    return {
        "score": round(momentum_score, 3),
        "confidence": 0.4,
        "label": momentum_label,
        "source": "price-momentum-estimate",
        "headlines": [],
    }