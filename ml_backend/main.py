import datetime as dt
import logging
import os
import time

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import CACHE_TTL_SECONDS, SYMBOLS
from services import backtest, tuner
from services.data_service import data_service
from services.indicators import compute_all
from services.predictor import predict
from services.sentiment import analyze as analyze_sentiment
from services.signal import build_signal

PORT = int(os.getenv("PORT", "8000"))

RESPONSE_CACHE_TTL_SECONDS = int(os.getenv("RESPONSE_CACHE_TTL_SECONDS", "180"))
_response_cache: dict[str, dict] = {}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api")

app = FastAPI(
    title="Cangcilung Trading AI API",
    version="1.0.0",
    description="Prediksi harga, technical indicators, sentiment, dan sinyal trading untuk XAUUSD, NASDAQ, AUDUSD.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def serialize_datetime(index):
    try:
        return index.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (AttributeError, ValueError):
        return str(index)


@app.get("/health")
def health():
    return {"status": "ok", "time": dt.datetime.utcnow().isoformat() + "Z"}


@app.get("/")
def root():
    return {
        "name": "Cangcilung Trading AI",
        "symbols": {k: v["yahoo"] for k, v in SYMBOLS.items()},
        "docs": "/docs",
    }


def _build_payload(symbol: str) -> dict:
    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)

    ind = compute_all(df)
    closes = df["Close"].to_numpy()
    prediction = predict(closes)

    last_close = ind["price"]
    prev_close = float(df["Close"].iloc[-2]) if len(df) > 1 else last_close
    change_pct = ((last_close - prev_close) / prev_close * 100) if prev_close else 0.0

    price_momentum = 0.0
    if len(closes) >= 20:
        price_momentum = float(closes[-1] / closes[-20] - 1.0)
    sentiment = analyze_sentiment(symbol, price_momentum)

    tuning = tuner.tuned(df, symbol)
    signal = build_signal(ind, prediction, sentiment, weights=tuning["weights"])

    candles = []
    last_rows = df.tail(40)
    for idx, row in last_rows.iterrows():
        candles.append(
            {
                "t": serialize_datetime(idx),
                "o": round(float(row["Open"]), 6),
                "h": round(float(row["High"]), 6),
                "l": round(float(row["Low"]), 6),
                "c": round(float(row["Close"]), 6),
                "v": int(row["Volume"]) if str(row["Volume"]) not in ("nan", "None") else 0,
            }
        )

    meta = SYMBOLS[symbol]
    return {
        "symbol": symbol,
        "name": meta["name"],
        "category": meta["category"],
        "decimals": meta["decimals"],
        "source_symbol": meta["yahoo"],
        "updated_at": dt.datetime.utcnow().isoformat() + "Z",
        "current_price": round(last_close, meta["decimals"]),
        "previous_close": round(prev_close, meta["decimals"]),
        "change_pct": round(change_pct, 3),
        "prediction": {
            "next_price": round(prediction["next_price"], meta["decimals"]),
            "horizon": prediction["horizon"],
            "direction": prediction["direction"],
            "confidence": prediction["confidence"],
            "ensembles": prediction.get("ensembles", 0),
        },
        "signal": signal,
        "indicators": ind,
        "sentiment": sentiment,
        "candles": candles,
        "data_points": len(df),
        "weights": tuning["weights"],
    }


@app.get("/backtest/{symbol}")
def get_backtest(symbol: str):
    symbol = symbol.upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")

    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
    tuning = tuner.tuned(df, symbol)

    tuned_metrics = backtest.run(df, weights=tuning["weights"])
    default_metrics = backtest.run(df)

    return {
        "symbol": symbol,
        "trained_at": dt.datetime.fromtimestamp(tuning["at"]).isoformat() + "Z",
        "weights": tuning["weights"],
        "multipliers": tuning["multipliers"],
        "default": default_metrics,
        "tuned": tuned_metrics,
        "difference": {
            "win_rate": round(tuned_metrics["win_rate"] - default_metrics["win_rate"], 4),
            "profit_factor_delta": tuned_metrics["profit_factor"] - default_metrics.get("profit_factor") if default_metrics.get("profit_factor") and tuned_metrics.get("profit_factor") else None,
            "total_return": round(tuned_metrics["total_return"] - default_metrics["total_return"], 4),
        },
    }


@app.get("/stats/{symbol}")
def get_stats(symbol: str):
    symbol = symbol.upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")

    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
    tuning = tuner.tuned(df, symbol)
    close = df["Close"].to_numpy()

    acc_now = backtest.rolling(close, weights=tuning["weights"])
    acc_skip = backtest.rolling(close, weights=tuning["weights"], skip=0)
    acc_hist = backtest.rolling(close, weights=tuning["weights"], skip=30)

    # Verdict: tren akurasi (membaik/memburuk) + label kualitas
    w30 = acc_hist.get("14d", {}).get("win_rate")
    w7 = acc_now.get("7d", {}).get("win_rate")
    trend = "improving" if w7 and w30 and w7 > w30 else ("declining" if w7 is not None and w30 is not None and w7 < w30 else "stable")
    latest = max(acc_now.get("7d", {}).get("win_rate", 0.0), acc_now.get("14d", {}).get("win_rate", 0.0), acc_now.get("30d", {}).get("win_rate", 0.0))
    quality = "good" if latest >= 0.55 else ("average" if latest >= 0.45 else "weak")

    return {
        "symbol": symbol,
        "weights": tuning["weights"],
        "accuracy": acc_now,
        "accuracy_30d_ago": acc_hist,
        "trend": trend,
        "quality": quality,
        "trained_at": dt.datetime.fromtimestamp(tuning["at"]).isoformat() + "Z",
    }


@app.get("/model")
def model_info():
    out = {}
    for symbol in SYMBOLS:
        cached = tuner.get_cached(symbol)
        if not cached:
            try:
                df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
                cached = tuner.tuned(df, symbol)
            except Exception as exc:  # noqa: BLE001
                out[symbol] = {"error": str(exc)}
                continue
        try:
            closes = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)["Close"].to_numpy()
            acc = backtest.rolling(closes, weights=cached["weights"])
        except Exception:  # noqa: BLE001
            acc = {}
        out[symbol] = {
            "trained_at": dt.datetime.fromtimestamp(cached["at"]).isoformat() + "Z",
            "weights": cached["weights"],
            "multipliers": cached["multipliers"],
            "backtest": cached["metrics"],
            "rolling_accuracy": acc,
        }
    return {
        "strategy": "grid-search auto-tune per symbol (walk-forward backtest)",
        "lookbacks": [12, 24, 36],
        "symbols": out,
    }


@app.get("/signal/{symbol}")
def get_signal(symbol: str):
    symbol = symbol.upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")

    now = time.time()
    cached = _response_cache.get(symbol)
    if cached and cached["expires"] > now:
        return cached["payload"]

    payload = _build_payload(symbol)
    _response_cache[symbol] = {"expires": time.time() + RESPONSE_CACHE_TTL_SECONDS, "payload": payload}
    return payload


@app.get("/warm")
def warmup():
    results = {}
    for symbol in SYMBOLS:
        now = time.time()
        cached = _response_cache.get(symbol)
        if cached and cached["expires"] > now:
            results[symbol] = "cached"
            continue
        try:
            payload = _build_payload(symbol)
            _response_cache[symbol] = {"expires": time.time() + RESPONSE_CACHE_TTL_SECONDS, "payload": payload}
            results[symbol] = "ok"
        except Exception as exc:  # noqa: BLE001
            logger.warning("warmup %s failed: %s", symbol, exc)
            results[symbol] = f"error: {exc}"
    return {"status": "ok", "symbols": results}