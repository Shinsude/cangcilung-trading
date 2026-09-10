import datetime as dt
import json
import logging
import os
import time

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import CACHE_TTL_SECONDS, SYMBOLS
from services import backtest, timeframe, tuner
from services.data_service import data_service
from services.indicators import compute_all
from services.predictor import predict, directional_accuracy, hp_validation
from services.sentiment import analyze as analyze_sentiment
from services.signal import build_signal

PORT = int(os.getenv("PORT", "8000"))

RESPONSE_CACHE_TTL_SECONDS = int(os.getenv("RESPONSE_CACHE_TTL_SECONDS", "180"))
_response_cache: dict[str, dict] = {}

LOG_URL = os.getenv("SIGNALS_LOG_URL", "https://raw.githubusercontent.com/Shinsude/cangcilung-trading/main/flutter_app/web/signals_log.json")
_real_log_cache: dict = {}

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


MODEL_CACHE_TTL = 300
_model_cache: list = [0.0, None]  # [at, body]

CAL_CACHE_TTL = 300
_calendar_cache: list = [0.0, None]  # [at, body]
CALENDAR_URL = os.getenv("CALENDAR_URL", "https://nfs.faireconomy.media/ff_calendar_thisweek.json")


def _fetch_calendar(hours: int) -> dict:
    now = time.time()
    hit = _calendar_cache[1]
    if hit and now - _calendar_cache[0] < CAL_CACHE_TTL:
        return hit
    import urllib.request

    try:
        req = urllib.request.Request(
            CALENDAR_URL,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
                "Accept": "application/json, text/plain, */*",
            },
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            raw = json.loads(r.read().decode("utf-8"))
        events = []
        wib = dt.timezone(dt.timedelta(hours=7))
        for e in raw:
            if str(e.get("impact", "")).strip().lower() == "low":
                continue
            date = e.get("date")
            try:
                dt0 = dt.datetime.fromisoformat(date).astimezone(dt.timezone.utc)
            except Exception:  # noqa: BLE001
                continue
            ts = int(dt0.timestamp() * 1000)
            if ts < now * 1000 or ts > (now + hours * 3600) * 1000:
                continue
            loc = dt.datetime.fromtimestamp(ts / 1000, tz=dt.timezone.utc).astimezone(wib)
            events.append(
                {
                    "title": str(e.get("title", "")),
                    "country": str(e.get("country", "")),
                    "impact": str(e.get("impact", "")),
                    "ts": ts,
                    "time_wib": loc.strftime("%H:%M"),
                }
            )
        events.sort(key=lambda x: x["ts"])
        body = {"events": events[:12]}
        _calendar_cache[0] = now
        _calendar_cache[1] = body
        return body
    except Exception as exc:  # noqa: BLE001
        if hit:
            return hit
        return {"events": [], "warning": str(exc)}


def serialize_datetime(index):
    try:
        return index.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (AttributeError, ValueError):
        return str(index)


@app.get("/health")
def health():
    return {"status": "ok", "time": dt.datetime.utcnow().isoformat() + "Z"}


@app.get("/calendar")
def calendar(hours: int = 48):
    hours_s = max(6, min(int(hours), 96))
    return _fetch_calendar(hours_s)


def _fetch_real_log(ttl: int = 300) -> list:
    now = time.time()
    hit = _real_log_cache.get("log")
    if hit and now - hit["at"] < ttl:
        return hit["data"]
    import urllib.request

    try:
        with urllib.request.urlopen(LOG_URL, timeout=20) as r:
            data = json.loads(r.read().decode("utf-8"))
        _real_log_cache["log"] = {"at": now, "data": data}
        return data
    except Exception:  # noqa: BLE001
        return hit["data"] if hit else []


def _real_accuracy(log_entries: list, symbol: str, df) -> dict:
    try:
        dates = {idx.strftime("%Y-%m-%d"): i for i, idx in enumerate(df.index)}
        wins = 0
        cnt = 0
        for e in log_entries:
            if e.get("symbol") != symbol:
                continue
            i = dates.get(e.get("date"))
            if i is None or i + 1 >= len(df):
                continue
            c0 = float(df.iloc[i]["Close"])
            c1 = float(df.iloc[i + 1]["Close"])
            if c1 == c0:
                continue
            actual_up = c1 > c0
            expected_up = e.get("action") == "BUY"
            cnt += 1
            if actual_up == expected_up:
                wins += 1
        return {
            "samples": cnt,
            "win_rate": round(wins / cnt, 3) if cnt else None,
        }
    except Exception:  # noqa: BLE001
        return {"samples": 0, "win_rate": None}


@app.get("/")
def root():
    return {
        "name": "Cangcilung Trading AI",
        "symbols": {k: v["yahoo"] for k, v in SYMBOLS.items()},
        "docs": "/docs",
    }


def _profit_plan(ind: dict, action: str, price: float, decimals: int) -> dict:
    atr = ind.get("atr")
    if not atr or atr <= 0:
        return {"entry": round(price, decimals), "note": "ATR tidak tersedia"}
    side = action if action in ("BUY", "SELL") else None
    base = {"entry": round(price, decimals), "atr": round(atr, decimals)}
    if side is None:
        return {**base, "note": "Tunggu sinyal BUY/SELL untuk plan entry"}
    sl_mult, tp_mult = 1.5, 2.5
    if side == "BUY":
        stop = price - sl_mult * atr
        take = price + tp_mult * atr
    else:
        stop = price + sl_mult * atr
        take = price - tp_mult * atr
    risk_dist = abs(stop - price)
    rr = round(abs(take - price) / risk_dist, 2) if risk_dist > 0 else 0.0
    return {
        **base,
        "side": side,
        "stop_loss": round(stop, decimals),
        "take_profit": round(take, decimals),
        "risk_reward": rr,
    }


def _build_payload(symbol: str) -> dict:
    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)

    ind = compute_all(df)
    closes = df["Close"].to_numpy()
    prediction = predict(closes, df=df)

    last_close = ind["price"]
    prev_close = float(df["Close"].iloc[-2]) if len(df) > 1 else last_close
    change_pct = ((last_close - prev_close) / prev_close * 100) if prev_close else 0.0

    price_momentum = 0.0
    if len(closes) >= 20:
        price_momentum = float(closes[-1] / closes[-20] - 1.0)
    sentiment = analyze_sentiment(symbol, price_momentum)

    tuning = tuner.tuned(df, symbol)

    df_1h = df_4h = None
    try:
        df_1h = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS, interval="1h", period="1mo")
    except Exception:  # noqa: BLE001
        pass
    try:
        df_4h = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS, interval="4h", period="3mo")
    except Exception:  # noqa: BLE001
        pass
    tf_value, tf_parts = timeframe.alignment(df_1h, df_4h)

    signal = build_signal(ind, prediction, sentiment, weights=tuning["weights"], extra=tf_value * timeframe.TF_WEIGHT)

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
        "risk": _profit_plan(ind, signal["action"], last_close, meta["decimals"]),
        "indicators": ind,
        "sentiment": sentiment,
        "candles": candles,
        "data_points": len(df),
        "weights": tuning["weights"],
        "timeframe": {"value": tf_value, "parts": tf_parts},
    }


@app.get("/backtest/{symbol}")
def get_backtest(symbol: str, days: int | None = None):
    symbol = symbol.upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")

    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
    tuning = tuner.tuned(df, symbol)

    if days and days > 0:
        df = df.tail(days)

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

    acc_now = backtest.rolling(close, weights=tuning["weights"], df=df)
    acc_skip = backtest.rolling(close, weights=tuning["weights"], skip=0, df=df)
    acc_hist = backtest.rolling(close, weights=tuning["weights"], skip=30, df=df)

    real = _real_accuracy(_fetch_real_log(), symbol, df)

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
        "real_accuracy": real,
        "trend": trend,
        "quality": quality,
        "trained_at": dt.datetime.fromtimestamp(tuning["at"]).isoformat() + "Z",
    }


@app.get("/model")
def model_info():
    now = time.time()
    if _model_cache[0] and now - _model_cache[0] < MODEL_CACHE_TTL:
        return _model_cache[1]
    out: dict = {}

    def _work(symbol: str) -> tuple[str, dict]:
        cached = tuner.get_cached(symbol)
        if not cached:
            try:
                df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
                cached = tuner.tuned(df, symbol)
            except Exception as exc:  # noqa: BLE001
                return symbol, {"error": str(exc)}
        try:
            mdf = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
            acc = backtest.rolling(mdf["Close"].to_numpy(), weights=cached["weights"], df=mdf)
        except Exception:  # noqa: BLE001
            acc = {}
        try:
            mlp_acc = directional_accuracy(mdf["Close"].to_numpy(), df=mdf)
        except Exception as exc:  # noqa: BLE001
            mlp_acc = {"error": f"{type(exc).__name__}: {exc}"}
        try:
            hp = hp_validation(mdf["Close"].to_numpy(), df=mdf)
        except Exception:  # noqa: BLE001
            hp = {"error": "hp validation failed"}
        real = _real_accuracy(_fetch_real_log(), symbol, mdf)
        return symbol, {
            "trained_at": dt.datetime.fromtimestamp(cached["at"]).isoformat() + "Z",
            "weights": cached["weights"],
            "multipliers": cached["multipliers"],
            "backtest": cached["metrics"],
            "rolling_accuracy": acc,
            "mlp_validation": mlp_acc,
            "hp_validation": hp,
            "real_accuracy": real,
        }

    for symbol in SYMBOLS:
        sym, payload = _work(symbol)
        out[sym] = payload

    body = {
        "strategy": "grid-search auto-tune per symbol (walk-forward backtest)",
        "lookbacks": [12, 24, 36],
        "symbols": out,
    }
    _model_cache[0] = time.time()
    _model_cache[1] = body
    return body


@app.get("/history/{symbol}")
def get_history(symbol: str, limit: int = 30):
    symbol = symbol.upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")

    try:
        df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
        log = _fetch_real_log()
        dates = {idx.strftime("%Y-%m-%d"): i for i, idx in enumerate(df.index)}
        entries = [e for e in log if e.get("symbol") == symbol]
        enriched = []
        for e in entries:
            i = dates.get(e.get("date"))
            outcome = "pending"
            c_then = c_next = None
            if i is not None:
                c_then = round(float(df.iloc[i]["Close"]), 6)
                if i + 1 < len(df):
                    c_next = round(float(df.iloc[i + 1]["Close"]), 6)
                    if c_next != c_then:
                        actual_up = c_next > c_then
                        expected_up = e.get("action") == "BUY"
                        outcome = "win" if actual_up == expected_up else "loss"
                    else:
                        outcome = "tie"
            enriched.append({
                "date": e.get("date"),
                "action": e.get("action"),
                "strength": e.get("strength"),
                "score": e.get("score"),
                "close_then": c_then,
                "close_next": c_next,
                "outcome": outcome,
            })
        enriched.sort(key=lambda x: x.get("date", ""), reverse=True)
        return enriched[:limit]
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc), "entries": []}


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