def build_signal(ind, prediction, sentiment) -> dict:
    score = 0.0

    rsi = ind["rsi"]
    if rsi["region"] == "oversold":
        score += 1.5
    elif rsi["region"] == "overbought":
        score -= 1.5
    elif 45 <= rsi["value"] <= 55:
        score += 0.1

    macd_state = ind["macd"]
    if macd_state["cross"] == "bullish":
        score += 2.0
    elif macd_state["cross"] == "bearish":
        score -= 2.0
    score += 0.8 if macd_state["histogram"] > 0 else -0.8

    ema_state = ind["ema"]
    score += 1.2 if ema_state["trend"] == "bullish" else -1.2
    if ema_state["ema9"] > ema_state["ema21"] > ema_state["ema50"]:
        score += 0.8
    elif ema_state["ema9"] < ema_state["ema21"] < ema_state["ema50"]:
        score -= 0.8

    bb = ind["bollinger"]
    if bb["percent_b"] is not None:
        if bb["percent_b"] < 0.05:
            score += 0.6
        elif bb["percent_b"] > 0.95:
            score -= 0.6

    pred_dir = prediction["direction"]
    pred_conf = prediction["confidence"]
    score += (pred_conf * 2.0) if pred_dir == "UP" else (-pred_conf * 2.0 if pred_dir == "DOWN" else 0.0)

    sent_score = sentiment.get("score", 0.0)
    score += sent_score * 1.5

    if score >= 1.5:
        action = "BUY"
        strength = "STRONG" if score >= 3.0 else "MODERATE"
    elif score <= -1.5:
        action = "SELL"
        strength = "STRONG" if score <= -3.0 else "MODERATE"
    else:
        action = "HOLD"
        strength = "WEAK"

    confidence = min(0.95, max(0.3, abs(score) / 5.0 + (0.35 if abs(score) >= 1.5 else 0.1)))
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