DEFAULT_WEIGHTS = {
    "rsi": 1.0,
    "macd_cross": 1.0,
    "macd_hist": 1.0,
    "ema_trend": 1.0,
    "ema_alignment": 1.0,
    "bb": 1.0,
    "prediction": 1.0,
    "sentiment": 1.0,
    "volume": 1.0,
    "sr": 1.0,
}

DEFAULT_THRESHOLDS = {
    "buy": 1.5,
    "sell": -1.5,
    "strong": 3.0,
}


def build_signal(ind, prediction, sentiment, weights: dict | None = None, thresholds: dict | None = None, extra: float = 0.0) -> dict:
    w = {**DEFAULT_WEIGHTS, **(weights or {})}
    t = {**DEFAULT_THRESHOLDS, **(thresholds or {})}
    score = 0.0

    rsi = ind["rsi"]
    if rsi["region"] == "oversold":
        score += 1.5 * w["rsi"]
    elif rsi["region"] == "overbought":
        score -= 1.5 * w["rsi"]
    elif 45 <= rsi["value"] <= 55:
        score += 0.1 * w["rsi"]

    macd_state = ind["macd"]
    if macd_state["cross"] == "bullish":
        score += 2.0 * w["macd_cross"]
    elif macd_state["cross"] == "bearish":
        score -= 2.0 * w["macd_cross"]
    score += (0.8 if macd_state["histogram"] > 0 else -0.8) * w["macd_hist"]

    ema_state = ind["ema"]
    score += (1.2 if ema_state["trend"] == "bullish" else -1.2) * w["ema_trend"]
    if ema_state["ema9"] > ema_state["ema21"] > ema_state["ema50"]:
        score += 0.8 * w["ema_alignment"]
    elif ema_state["ema9"] < ema_state["ema21"] < ema_state["ema50"]:
        score -= 0.8 * w["ema_alignment"]

    bb = ind["bollinger"]
    if bb["percent_b"] is not None:
        if bb["percent_b"] < 0.05:
            score += 0.6 * w["bb"]
        elif bb["percent_b"] > 0.95:
            score -= 0.6 * w["bb"]

    # Volume konfirmasi tren (+/- tergantung arah + kekuatan relatif)
    vol_conf = ind.get("volume", 0.0)
    score += max(-1.0, min(1.0, vol_conf)) * 0.8 * w["volume"]

    # Posisi support/resistance: harga mendekati resistance (atas) = bearish/sell,
    # mendekati support (bawah) = bullish/buy (mean-reversion)
    sr_pos = ind.get("sr", 0.5)
    if sr_pos > 0.8:
        score -= 0.6 * w["sr"]
    elif sr_pos < 0.2:
        score += 0.6 * w["sr"]

    pred_dir = prediction["direction"]
    pred_conf = prediction["confidence"]
    score += (pred_conf * 2.0 if pred_dir == "UP" else -pred_conf * 2.0 if pred_dir == "DOWN" else 0.0) * w["prediction"]

    sent_score = sentiment.get("score", 0.0)
    score += sent_score * 1.5 * w["sentiment"]

    score += extra

    buy_th = t["buy"]
    sell_th = t["sell"]
    strong_th = t["strong"]

    if score >= buy_th:
        action = "BUY"
        strength = "STRONG" if score >= strong_th else "MODERATE"
    elif score <= sell_th:
        action = "SELL"
        strength = "STRONG" if score <= -strong_th else "MODERATE"
    else:
        action = "HOLD"
        strength = "WEAK"

    confidence = min(0.95, max(0.3, abs(score) / 5.0 + (0.35 if abs(score) >= buy_th else 0.1)))
    summary = _summary(action, strength, ind, pred_dir, sentiment.get("label", "NEUTRAL"))

    return {
        "action": action,
        "strength": strength,
        "confidence": round(confidence, 3),
        "score": round(score, 3),
        "summary": summary,
    }


def _summary(action, strength, ind, pred_dir, sent_label):
    reasons = []
    reasons.append(f"RSI {ind['rsi']['value']} ({ind['rsi']['region']})")
    reasons.append(f"MACD {ind['macd']['cross']}")
    reasons.append(f"EMA trend {ind['ema']['trend']}")
    if pred_dir != "NEUTRAL":
        reasons.append(f"AI {pred_dir}")
    reasons.append(f"sentiment {sent_label}")
    lead = {
        "BUY": "Momentum bullish terakumulasi" if strength == "STRONG" else "Indikasi bullish",
        "SELL": "Tekanan bearish kuat" if strength == "STRONG" else "Indikasi bearish",
        "HOLD": "Momentum masih netral",
    }[action]
    return f"{lead} ({', '.join(reasons)}). Sinyal ini hasil analisis statistik, bukan jaminan profit."