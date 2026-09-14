import collections
import datetime as dt
import json
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import CACHE_TTL_SECONDS, SYMBOLS
from services import backtest, timeframe, tuner
from services.data_service import data_service
from services.indicators import compute_all
from services.predictor import predict, directional_accuracy, hp_validation
from services.sentiment import analyze as analyze_sentiment
from services.signal import build_signal
from services.advanced import analyze as advanced_analyze

PORT = int(os.getenv("PORT", "8000"))

RESPONSE_CACHE_TTL_SECONDS = int(os.getenv("RESPONSE_CACHE_TTL_SECONDS", "600"))
_response_cache: dict[str, dict] = {}
_digest_cache: list = [0.0, None]  # [at, body]
DIGEST_CACHE_TTL = 600

LOG_URL = os.getenv("SIGNALS_LOG_URL", "https://raw.githubusercontent.com/Shinsude/cangcilung-trading/main/flutter_app/web/signals_log.json")
_real_log_cache: dict = {}
_signal_history: dict[str, list[str]] = {}  # symbol -> list of recent action strings
_sim_positions: dict[str, dict] = {}  # symbol -> simulated open position
_pipeline_stats: dict[str, collections.Counter] = {}  # symbol -> rolling counters

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


def _build_sim_position(symbol: str, plan: dict, price: float, decimals: int) -> dict:
    """Tracks a simulated open position from the latest actionable signal.

    Mirrors K-Synthesizer's open positions block without a live MT5 account:
    a BUY/SELL signal opens (or rolls) a position at the plan entry; while the
    same side persists the original entry is kept and live P&L is computed
    against the current price until TP/SL is hit.
    """
    side = plan.get("side")
    now_ts = dt.datetime.utcnow()
    pos = _sim_positions.get(symbol)

    if side is not None:
        if pos is None or pos["side"] != side or pos.get("closed"):
            pos = {
                "side": side,
                "entry": plan["entry"],
                "sl": plan.get("stop_loss", 0.0),
                "tp": plan.get("take_profit", 0.0),
                "trail_level": None,
                "trail_buffer": max(plan.get("atr", 0.0) * 0.75, 0.0),
                "profit_locked_pct": 0.0,
                "opened_at": now_ts.isoformat() + "Z",
                "closed": False,
            }
            _sim_positions[symbol] = pos

    if pos is None:
        return {"open": False}

    entry, sl, tp = pos["entry"], pos["sl"], pos["tp"]
    trail_level = pos.get("trail_level")
    buffer = pos.get("trail_buffer", 0.0)

    # ── Trailing stop: ratchet the stop toward price once in profit ──
    if pos["side"] == "BUY" and price > entry and buffer > 0:
        candidate = price - buffer
        if trail_level is None or candidate > trail_level:
            trail_level = candidate
        if sl > 0 and trail_level < sl:
            trail_level = sl
        pos["trail_level"] = trail_level
    elif pos["side"] == "SELL" and price < entry and buffer > 0:
        candidate = price + buffer
        if trail_level is None or candidate < trail_level:
            trail_level = candidate
        if sl > 0 and trail_level > sl:
            trail_level = sl
        pos["trail_level"] = trail_level

    effective_stop = trail_level if trail_level is not None else sl

    points = (price - entry) if pos["side"] == "BUY" else (entry - price)
    pnl = round(points, decimals)
    pnl_pct = round(points / entry * 100, 2) if entry else 0.0

    status = "OPEN"
    if effective_stop and entry:
        near_buy_stop = pos["side"] == "BUY" and price <= effective_stop
        near_sell_stop = pos["side"] == "SELL" and price >= effective_stop
        near_buy_tp = pos["side"] == "BUY" and tp > 0 and price >= tp
        near_sell_tp = pos["side"] == "SELL" and tp > 0 and price <= tp
        if near_buy_stop or near_sell_stop:
            status = "STOP"
        elif near_buy_tp or near_sell_tp:
            status = "TARGET"
    pos["closed"] = status != "OPEN"

    profit_locked = 0.0
    if trail_level is not None:
        locked_abs = (price - trail_level) if pos["side"] == "BUY" else (trail_level - price)
        profit_locked = max(0.0, locked_abs / entry * 100) if entry else 0.0
    pos["profit_locked_pct"] = round(profit_locked, 2)

    dist_stop = round(abs(price - (effective_stop or price)) / entry * 100, 2) if entry else 0.0
    dist_tp = round(abs(price - tp) / entry * 100, 2) if tp and entry else 0.0

    return {
        "open": status == "OPEN",
        "side": pos["side"],
        "entry_price": round(entry, decimals),
        "current_price": round(price, decimals),
        "stop_loss": round(sl, decimals),
        "take_profit": round(tp, decimals),
        "trail_level": round(trail_level, decimals) if trail_level is not None else None,
        "trail_active": trail_level is not None,
        "profit_locked_pct": pos["profit_locked_pct"],
        "points": pnl,
        "pnl_pct": pnl_pct,
        "dist_stop_pct": dist_stop,
        "dist_tp_pct": dist_tp,
        "status": status,
        "opened_at": pos["opened_at"],
    }


def _push_pipeline(symbol: str, signal: dict, advanced: dict) -> None:
    """Accumulate per-symbol rolling counters describing the signal pipeline."""
    c = _pipeline_stats.setdefault(symbol, collections.Counter())
    c["total"] += 1
    c[signal["action"]] += 1
    if advanced.get("is_dead_zone"):
        c["dead_zone"] += 1
    if advanced.get("ml_rejected"):
        c["ml_reject"] += 1
    grade = advanced.get("grade", "C")
    c[f"grade_{grade}"] += 1
    c["conf_sum"] += float(signal.get("confidence", 0.0))
    if c["total"] > 1000:
        _pipeline_stats[symbol] = collections.Counter()


def _build_pipeline(symbol: str) -> dict:
    c = _pipeline_stats.get(symbol)
    if not c or not c["total"]:
        return {"tracked": 0}
    total = int(c["total"])
    entry = int(c.get("BUY", 0)) + int(c.get("SELL", 0))
    holds = int(c.get("HOLD", 0))
    dead = int(c.get("dead_zone", 0))
    grades = ["ULTIMATE", "APLUS", "A", "BPLUS", "B", "C"]
    return {
        "tracked": total,
        "entry_rate": round(entry / total, 3),
        "hold_rate": round(holds / total, 3),
        "rejection_rate": round((holds + dead) / total, 3),
        "dead_zone_rate": round(dead / total, 3),
        "ml_reject_rate": round(c.get("ml_reject", 0) / total, 3),
        "avg_confidence": round(c["conf_sum"] / total, 3),
        "grade_distribution": {g: int(c.get(f"grade_{g}", 0)) for g in grades},
        "direction_counts": {"BUY": int(c.get("BUY", 0)), "SELL": int(c.get("SELL", 0)), "HOLD": holds},
    }


def _build_safety(plan: dict, atr: float) -> dict:
    """Check SL/TP are inside sane volatility bounds (K-Synthesizer safety)."""
    entry = plan.get("entry")
    sl = plan.get("stop_loss")
    tp = plan.get("take_profit")
    if entry is None or sl is None or tp is None or not atr or atr <= 0:
        return {"status": "N/A", "violations": 0, "note": "Belum ada plan entry"}
    sl_dist = abs(sl - entry)
    tp_dist = abs(tp - entry)
    ok_sl = sl_dist >= 0.5 * atr
    ok_rr = plan.get("risk_reward", 0.0) >= 1.0
    violations = (0 if ok_sl else 1) + (0 if ok_rr else 1)
    return {
        "status": "OK" if violations == 0 else "CHECK",
        "violations": violations,
        "minimum_stop": round(entry - 0.5 * atr, 2) if plan.get("side") == "BUY" else round(entry + 0.5 * atr, 2),
        "risk_reward": plan.get("risk_reward", 0.0),
    }


def _fetch_interval(symbol: str, interval: str, period: str):
    try:
        return data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS, interval=interval, period=period)
    except Exception:  # noqa: BLE001
        return None


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

    df_1h = df_4h = df_30m = df_15m = None
    with ThreadPoolExecutor(max_workers=4) as ex:
        futures = {
            "1h": ex.submit(_fetch_interval, symbol, "1h", "1mo"),
            "4h": ex.submit(_fetch_interval, symbol, "4h", "3mo"),
            "30m": ex.submit(_fetch_interval, symbol, "30m", "1mo"),
            "15m": ex.submit(_fetch_interval, symbol, "15m", "1mo"),
        }
        for name, fut in futures.items():
            try:
                dfx = fut.result()
            except Exception:  # noqa: BLE001
                dfx = None
            if name == "1h":
                df_1h = dfx
            elif name == "4h":
                df_4h = dfx
            elif name == "30m":
                df_30m = dfx
            else:
                df_15m = dfx
    tf_value, tf_parts = timeframe.alignment(df_1h, df_4h)

    signal = build_signal(ind, prediction, sentiment, weights=tuning["weights"], extra=tf_value * timeframe.TF_WEIGHT)

    hist = _signal_history.setdefault(symbol, [])
    hist.append(signal["action"])
    if len(hist) > 20:
        hist[:] = hist[-20:]

    advanced = advanced_analyze(
        df_1d=df,
        ind=ind,
        signal=signal,
        prediction=prediction,
        df_1h=df_1h,
        df_4h=df_4h,
        df_30m=df_30m,
        df_15m=df_15m,
        signal_history=hist,
    )
    _push_pipeline(symbol, signal, advanced)

    meta = SYMBOLS[symbol]
    plan = _profit_plan(ind, signal["action"], last_close, meta["decimals"])

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

    return {
        "symbol": symbol,
        "name": meta["name"],
        "category": meta["category"],
        "decimals": meta["decimals"],
        "source_symbol": meta["yahoo"],
        "data_source": data_service.source(symbol),
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
        "risk": plan,
        "safety": _build_safety(plan, ind.get("atr", 0)),
        "position": _build_sim_position(symbol, plan, last_close, meta["decimals"]),
        "pipeline": _build_pipeline(symbol),
        "indicators": ind,
        "sentiment": sentiment,
        "candles": candles,
        "data_points": len(df),
        "weights": tuning["weights"],
        "timeframe": {"value": tf_value, "parts": tf_parts},
        "advanced": advanced,
        "system": {
            "ts_intrinsic": advanced.get("ts_intrinsic", 0),
            "ts_snr": advanced.get("ts_snr", 0),
            "decomp_regime": advanced.get("decomp_regime", "NO DATA"),
            "bar_total": advanced.get("bar_total", 0),
            "theta": advanced.get("theta", {}),
            "safety": _build_safety(plan, ind.get("atr", 0)),
        },
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


_alerts_store: dict[str, dict] = {}  # id -> {device_id, symbol, target, created, triggered}
_alerts_seq: int = 0
_alert_devices: dict[str, set[str]] = {}  # symbol -> device ids


def _current_price(symbol: str) -> float:
    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
    return float(df["Close"].iloc[-1])


@app.get("/alerts")
def list_alerts(device_id: str = ""):
    did = (device_id or "").strip()
    active = [
        {
            "id": aid,
            "symbol": a["symbol"],
            "target": a["target"],
            "created": a["created"],
            "triggered": a["triggered"],
        }
        for aid, a in _alerts_store.items()
        if (not did or a["device_id"] == did)
    ]
    active.sort(key=lambda x: x["created"], reverse=True)
    return {"alerts": active}


@app.post("/alerts")
def create_alert(alert: dict):
    global _alerts_seq
    symbol = str(alert.get("symbol", "")).upper()
    if symbol not in SYMBOLS:
        raise HTTPException(status_code=404, detail=f"Symbol tidak didukung. Gunakan: {', '.join(SYMBOLS)}")
    raw = alert.get("target")
    try:
        target = float(raw) if raw is not None else None
    except (TypeError, ValueError):
        target = None
    # Batas masuk akal: target harus wajar terhadap skala harga simbol, bukan asal-angka.
    if not target or target <= 0:
        raise HTTPException(status_code=422, detail="target harus angka lebih dari 0")
    device = str(alert.get("device_id") or "default").strip() or "default"
    if len(device) > 64:
        raise HTTPException(status_code=422, detail="device_id terlalu panjang")

    # Satu alert aktif per simbol per device (dedup)
    for aid, a in list(_alerts_store.items()):
        if a["device_id"] == device and a["symbol"] == symbol and not a["triggered"]:
            _alerts_store.pop(aid, None)
            sym_set = _alert_devices.get(symbol)
            if sym_set:
                sym_set.discard(device)

    # Cap total alert per device (anti-spam/abuse serverless)
    device_count = sum(1 for a in _alerts_store.values() if a["device_id"] == device)
    if device_count >= 12:
        raise HTTPException(status_code=429, detail="Terlalu banyak alert aktif untuk perangkat ini (maks 12)")

    _alerts_seq += 1
    aid = f"al_{int(time.time())}_{_alerts_seq}"
    _alerts_store[aid] = {
        "device_id": device,
        "symbol": symbol,
        "target": target,
        "created": dt.datetime.utcnow().isoformat() + "Z",
        "triggered": False,
    }
    _alert_devices.setdefault(symbol, set()).add(device)
    return {"id": aid, "symbol": symbol, "target": target}


@app.delete("/alerts/{alert_id}")
def delete_alert(alert_id: str):
    a = _alerts_store.pop(alert_id, None)
    if a is None:
        raise HTTPException(status_code=404, detail="Alert tidak ditemukan")
    sym_set = _alert_devices.get(a["symbol"])
    if sym_set:
        sym_set.discard(a["device_id"])
    return {"ok": True}


@app.get("/alerts/check")
def check_alerts():
    """Evaluasi semua alert aktif terhadap harga terkini; tandai yang ter-trigger."""
    triggered: list[dict] = []
    still_active: list[dict] = []
    for aid, a in list(_alerts_store.items()):
        if a["triggered"]:
            continue
        try:
            price = _current_price(a["symbol"])
        except Exception:  # noqa: BLE001
            still_active.append(aid)
            continue
        if a["symbol"].upper() == "AUDUSD":
            hit = price <= a["target"]
        else:
            hit = price >= a["target"]
        if hit:
            a["triggered"] = True
            a["triggered_at"] = dt.datetime.utcnow().isoformat() + "Z"
            a["triggered_price"] = round(price, 5)
            triggered.append({
                "id": aid,
                "device_id": a["device_id"],
                "symbol": a["symbol"],
                "target": a["target"],
                "price": round(price, 5),
                "at": a["triggered_at"],
            })
        else:
            still_active.append(aid)
    return {"checked_at": dt.datetime.utcnow().isoformat() + "Z", "triggered": triggered, "active": len(still_active) + len(triggered)}


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


def _build_digest_row(symbol: str) -> dict:
    """Versi ringan untuk /digest: 1 fetch harian + indikator + prediksi saja.
    Menghindari 5 fetch interval + grid-search agar muat di batas waktu Lambda."""
    meta = SYMBOLS[symbol]
    try:
        cached = _response_cache.get(symbol)
        now = time.time()
        if cached and cached["expires"] > now:
            p = cached["payload"]
            sig = p.get("signal", {})
            pred = p.get("prediction", {})
            return {
                "symbol": symbol,
                "name": p.get("name", ""),
                "price": p.get("current_price"),
                "change_pct": p.get("change_pct", 0),
                "data_source": p.get("data_source", data_service.source(symbol)),
                "action": sig.get("action", "HOLD"),
                "strength": sig.get("strength", ""),
                "confidence": pred.get("confidence"),
                "direction": pred.get("direction", "NEUTRAL"),
                "next_price": pred.get("next_price"),
                "horizon": pred.get("horizon", ""),
            }
    except Exception:  # noqa: BLE001
        pass

    df = data_service.fetch(symbol, ttl=CACHE_TTL_SECONDS)
    ind = compute_all(df)
    closes = df["Close"].to_numpy()
    prediction = predict(closes, df=df)
    last_close = float(ind["price"])
    prev_close = float(df["Close"].iloc[-2]) if len(df) > 1 else last_close
    change_pct = ((last_close - prev_close) / prev_close * 100) if prev_close else 0.0
    momentum = float(closes[-1] / closes[-20] - 1.0) if len(closes) >= 20 else 0.0
    sentiment = analyze_sentiment(symbol, momentum)
    tuning = tuner.get_cached(symbol)
    weights = tuning["weights"] if tuning else None
    signal = build_signal(ind, prediction, sentiment, weights=weights)

    return {
        "symbol": symbol,
        "name": meta["name"],
        "price": round(last_close, meta["decimals"]),
        "change_pct": round(change_pct, 3),
        "data_source": data_service.source(symbol),
        "action": signal["action"],
        "strength": signal["strength"],
        "confidence": prediction.get("confidence"),
        "direction": prediction.get("direction", "NEUTRAL"),
        "next_price": prediction.get("next_price"),
        "horizon": prediction.get("horizon", ""),
    }


@app.get("/digest")
def get_digest():
    """Rekap harian pagi: ringkasan sinyal & prediksi untuk semua simbol dalam satu payload."""
    now_ts = time.time()
    if _digest_cache[0] and now_ts - _digest_cache[0] < DIGEST_CACHE_TTL:
        return _digest_cache[1]

    now = dt.datetime.utcnow()
    out: list[dict] = []
    for symbol in SYMBOLS:
        try:
            out.append(_build_digest_row(symbol))
        except Exception as exc:  # noqa: BLE001
            out.append({"symbol": symbol, "error": str(exc)})

    text_parts: list[str] = []
    for r in out:
        if r.get("error"):
            text_parts.append(f"{r['symbol']} GAGAL")
            continue
        sym = r["symbol"]
        act = r["action"]
        if act == "HOLD":
            text_parts.append(f"{sym} HOLD")
            continue
        conf = f"{int(r['confidence'] * 100)}%" if isinstance(r.get("confidence"), (int, float)) and r["confidence"] else ""
        arrow = "naik" if r.get("direction") == "UP" else "turun"
        np_ = r.get("next_price")
        nud = f" ke {np_:,.4f}".rstrip("0").rstrip(".") if isinstance(np_, (int, float)) else ""
        text_parts.append(f"{sym} {act} ({conf}) {arrow}{nud}")

    header = {
        "date": now.strftime("%Y-%m-%d"),
        "generated_at": now.isoformat() + "Z",
    }
    if not text_parts:
        body = {**header, "text": "Belum ada sinyal hari ini.", "symbols": out}
    else:
        body = {**header, "text": "Rekap pagi: " + ", ".join(text_parts) + ".", "symbols": out}
    _digest_cache[0] = now_ts
    _digest_cache[1] = body
    return body