"""Advanced signal analysis: MTF alignment, session detection, grade system,
stability, divergence, and composite scoring — inspired by K-Synthesizer (TCIP)."""
import datetime as _dt
import math
import numpy as np
import pandas as pd

from services.indicators import ema, rsi as compute_rsi, macd as compute_macd, bollinger as compute_bollinger


# ── Session Detection ──────────────────────────────────────────────────────

SESSIONS = [
    {"name": "ASIA", "start_h": 0, "end_h": 9, "color": "cyan"},
    {"name": "LONDON", "start_h": 8, "end_h": 17, "color": "green"},
    {"name": "NEW_YORK", "start_h": 13, "end_h": 22, "color": "amber"},
]

_OVERLAP_LABELS = {
    frozenset({"ASIA", "LONDON"}): "ASIA→LONDON",
    frozenset({"LONDON", "NEW_YORK"}): "LONDON→NY",
    frozenset({"ASIA", "NEW_YORK"}): "ASIA→NY",
}


def detect_session(now_utc: _dt.datetime | None = None) -> dict:
    """Return current trading session info based on UTC hour."""
    if now_utc is None:
        now_utc = _dt.datetime.utcnow()
    h = now_utc.hour + now_utc.minute / 60.0
    active = []
    for s in SESSIONS:
        if s["start_h"] <= h < s["end_h"]:
            active.append(s["name"])
    name = "CLOSED"
    if len(active) == 1:
        name = active[0]
    elif len(active) >= 2:
        key = frozenset(active[:2])
        name = _OVERLAP_LABELS.get(key, "+".join(active))
    return {
        "session": name,
        "active_sessions": active,
        "hour_utc": round(h, 2),
    }


# ── MTF Analysis ───────────────────────────────────────────────────────────

def _compute_tf_bias(df: pd.DataFrame) -> dict:
    """Compute directional bias for a single timeframe."""
    if df is None or len(df) < 30:
        return {"direction": "NEUTRAL", "score": 0}
    closes = df["Close"].astype(float)
    price = float(closes.iloc[-1])
    e12 = float(ema(closes, 12).iloc[-1])
    e26 = float(ema(closes, 26).iloc[-1])
    rsi_val = float(compute_rsi(closes).iloc[-1]) if len(closes) > 14 else 50.0
    macd_line, macd_sig, macd_hist = compute_macd(closes)
    hist_now = float(macd_hist.iloc[-1])

    score = 0.0
    if price > e12 > e26:
        score += 0.4
    elif price < e12 < e26:
        score -= 0.4
    if rsi_val > 55:
        score += 0.15
    elif rsi_val < 45:
        score -= 0.15
    if hist_now > 0:
        score += 0.15
    elif hist_now < 0:
        score -= 0.15

    direction = "NEUTRAL"
    if score >= 0.3:
        direction = "BULLISH"
    elif score <= -0.3:
        direction = "BEARISH"
    return {"direction": direction, "score": round(score, 3)}


def compute_mtf(df_1d: pd.DataFrame, df_1h: pd.DataFrame | None = None, df_4h: pd.DataFrame | None = None,
                df_30m: pd.DataFrame | None = None, df_15m: pd.DataFrame | None = None) -> dict:
    """Compute multi-timeframe bias stack across D1/H4/H1/M30/M15 (K-Synthesizer style).

    The alignment aggregate stays anchored on the D1/H4/H1 triad so existing grade
    and alignment thresholds remain unchanged; M30/M15 are reported as extra layers.
    """
    d1 = _compute_tf_bias(df_1d)
    h4 = _compute_tf_bias(df_4h) if df_4h is not None else {"direction": "NEUTRAL", "score": 0}
    h1 = _compute_tf_bias(df_1h) if df_1h is not None else {"direction": "NEUTRAL", "score": 0}
    m30 = _compute_tf_bias(df_30m) if df_30m is not None else {"direction": "NEUTRAL", "score": 0}
    m15 = _compute_tf_bias(df_15m) if df_15m is not None else {"direction": "NEUTRAL", "score": 0}

    bullish_count = sum(1 for tf in [d1, h4, h1] if tf["direction"] == "BULLISH")
    bearish_count = sum(1 for tf in [d1, h4, h1] if tf["direction"] == "BEARISH")
    total = 3
    alignment = (bullish_count - bearish_count) / total

    if alignment >= 0.5:
        primary = "BULLISH"
    elif alignment <= -0.5:
        primary = "BEARISH"
    else:
        primary = "NEUTRAL"

    return {
        "mtf_d1_dir": d1["direction"],
        "mtf_d1_score": round(d1["score"] * 100),
        "mtf_h4_dir": h4["direction"],
        "mtf_h4_score": round(h4["score"] * 100),
        "mtf_h1_dir": h1["direction"],
        "mtf_h1_score": round(h1["score"] * 100),
        "mtf_m30_dir": m30["direction"],
        "mtf_m30_score": round(m30["score"] * 100),
        "mtf_m15_dir": m15["direction"],
        "mtf_m15_score": round(m15["score"] * 100),
        "mtf_alignment": round(alignment, 3),
        "mtf_primary": primary,
    }


# ── Grade System ───────────────────────────────────────────────────────────

def compute_grade(score: float, confidence: float, mtf_alignment: float) -> str:
    abs_score = abs(score)
    avg = (abs_score / 6.0 + confidence + abs(mtf_alignment)) / 3.0
    if avg >= 0.85:
        return "ULTIMATE"
    if avg >= 0.72:
        return "APLUS"
    if avg >= 0.58:
        return "A"
    if avg >= 0.42:
        return "BPLUS"
    if avg >= 0.28:
        return "B"
    return "C"


# ── Stability Score ────────────────────────────────────────────────────────

def compute_stability(signal_history: list[str], window: int = 10) -> str:
    if len(signal_history) < 3:
        return "UNKNOWN"
    recent = signal_history[-window:]
    same = sum(1 for s in recent if s == recent[0])
    ratio = same / len(recent)
    if ratio >= 0.8:
        return "HIGH"
    if ratio >= 0.5:
        return "MEDIUM"
    return "LOW"


# ── Divergence Detection ───────────────────────────────────────────────────

def detect_divergence(df: pd.DataFrame) -> str:
    if df is None or len(df) < 30:
        return "NONE"
    closes = df["Close"].astype(float)
    rsi_vals = compute_rsi(closes)
    lookback = min(14, len(df) - 1)
    price_now = float(closes.iloc[-1])
    price_prev = float(closes.iloc[-lookback])
    rsi_now = float(rsi_vals.iloc[-1])
    rsi_prev = float(rsi_vals.iloc[-lookback])

    if price_now < price_prev and rsi_now > rsi_prev:
        return "BULLISH"
    if price_now > price_prev and rsi_now < rsi_prev:
        return "BEARISH"
    return "NONE"


# ── Bar Strength ───────────────────────────────────────────────────────────

def compute_bar_level(df: pd.DataFrame) -> str:
    if df is None or len(df) < 5:
        return "UNKNOWN"
    last5 = df.tail(5)
    bodies = (last5["Close"] - last5["Open"]).abs()
    avg_body = float(bodies.mean())
    price = float(df["Close"].iloc[-1])
    if price <= 0:
        return "UNKNOWN"
    body_ratio = avg_body / price
    if body_ratio > 0.015:
        return "STRONG"
    if body_ratio > 0.008:
        return "MODERATE"
    if body_ratio > 0.003:
        return "WEAK"
    return "DEAD"


# ── Trend Consistency ──────────────────────────────────────────────────────

def compute_trend_consistency(df: pd.DataFrame) -> float:
    if df is None or len(df) < 10:
        return 0.5
    closes = df["Close"].astype(float).tail(20)
    changes = closes.diff().dropna()
    ups = (changes > 0).sum()
    total = len(changes)
    if total == 0:
        return 0.5
    return round(ups / total, 3)


# ── Technical Scores (CONF, CMP, CHR, CAL, UNI, TECH) ─────────────────────

def compute_tech_scores(ind: dict, signal_score: float, prediction: dict, mtf_alignment: float) -> dict:
    rsi_val = ind["rsi"]["value"]
    macd_hist = ind["macd"]["histogram"]
    bb_pct = ind["bollinger"].get("percent_b") or 0.5
    ema_trend = 1.0 if ind["ema"]["trend"] == "bullish" else -1.0

    # TECH: aggregate of indicator strengths
    rsi_contrib = max(-1, min(1, (50 - rsi_val) / 30))
    macd_contrib = max(-1, min(1, macd_hist * 100))
    bb_contrib = max(-1, min(1, (0.5 - bb_pct) * 2))
    tech = (rsi_contrib + macd_contrib + bb_contrib + ema_trend) / 4.0
    tech_score = round(max(0, min(100, (tech + 1) / 2 * 100)), 1)

    # CONF: confluence of indicators agreeing with signal direction
    pred_dir = prediction.get("direction", "NEUTRAL")
    agreeing = 0
    total = 5
    if signal_score > 0 and pred_dir == "UP":
        agreeing += 1
    elif signal_score < 0 and pred_dir == "DOWN":
        agreeing += 1
    if ema_trend > 0 and signal_score > 0:
        agreeing += 1
    elif ema_trend < 0 and signal_score < 0:
        agreeing += 1
    if macd_hist > 0 and signal_score > 0:
        agreeing += 1
    elif macd_hist < 0 and signal_score < 0:
        agreeing += 1
    if rsi_val < 50 and signal_score > 0:
        agreeing += 1
    elif rsi_val > 50 and signal_score < 0:
        agreeing += 1
    if bb_pct < 0.5 and signal_score > 0:
        agreeing += 1
    elif bb_pct > 0.5 and signal_score < 0:
        agreeing += 1
    conf_score = round(agreeing / total * 100, 1)

    # CMP: composite of signal + MTF + prediction
    cmp_val = (abs(signal_score) / 6.0 + abs(mtf_alignment) + prediction.get("confidence", 0)) / 3.0
    cmp_score = round(cmp_val * 100, 1)

    # CHR: coherence — how consistent indicators are with each other
    indicator_directions = [ema_trend, 1 if macd_hist > 0 else -1, 1 if rsi_val > 50 else -1, 1 if bb_pct > 0.5 else -1]
    agreement = abs(sum(indicator_directions)) / len(indicator_directions)
    chr_score = round(agreement * 100, 1)

    # CAL: calibrated confidence
    raw_conf = prediction.get("confidence", 0.5)
    penalty = 0.0
    if abs(mtf_alignment) < 0.3:
        penalty += 0.1
    if agreement < 0.5:
        penalty += 0.1
    cal_score = round(max(0, min(100, (raw_conf - penalty) * 100)), 1)

    # UNI: unified score
    uni = (conf_score + cmp_score + chr_score + cal_score + tech_score) / 5.0
    uni_score = round(uni, 1)

    return {
        "conf_score": conf_score,
        "cmp_score": cmp_score,
        "chr_score": chr_score,
        "cal_score": cal_score,
        "tech_score": tech_score,
        "uni_score": uni_score,
    }


# ── Risk Level ─────────────────────────────────────────────────────────────

def compute_risk_level(confidence: float, stability: str, divergence: str, bar_level: str) -> str:
    risk = 0
    if confidence < 0.4:
        risk += 2
    elif confidence < 0.6:
        risk += 1
    if stability == "LOW":
        risk += 2
    elif stability == "MEDIUM":
        risk += 1
    if divergence != "NONE":
        risk += 1
    if bar_level in ("WEAK", "DEAD"):
        risk += 1
    if risk >= 4:
        return "HIGH"
    if risk >= 2:
        return "MODERATE"
    return "LOW"


# ── SMC Warning ────────────────────────────────────────────────────────────

def detect_smc_warning(df: pd.DataFrame) -> bool:
    if df is None or len(df) < 20:
        return False
    highs = df["High"].astype(float).tail(20)
    lows = df["Low"].astype(float).tail(20)
    price = float(df["Close"].iloc[-1])
    swing_high = float(highs.max())
    swing_low = float(lows.min())
    rng = swing_high - swing_low
    if rng <= 0:
        return False
    pos = (price - swing_low) / rng
    if pos > 0.9:
        return True
    if pos < 0.1:
        return True
    return False


# ── CVD Proxy (volume-weighted price direction) ───────────────────────────

def compute_cvd_efficiency(df: pd.DataFrame) -> float:
    if df is None or len(df) < 10 or "Volume" not in df:
        return 0.5
    tail = df.tail(10)
    closes = tail["Close"].astype(float)
    volumes = tail["Volume"].astype(float)
    buy_vol = 0.0
    sell_vol = 0.0
    for i in range(1, len(closes)):
        diff = float(closes.iloc[i] - closes.iloc[i - 1])
        vol = float(volumes.iloc[i]) if volumes.iloc[i] > 0 else 1.0
        if diff > 0:
            buy_vol += vol
        elif diff < 0:
            sell_vol += vol
    total = buy_vol + sell_vol
    if total == 0:
        return 0.5
    return round(buy_vol / total, 3)


# ── Weighted Alignment ─────────────────────────────────────────────────────

def compute_weighted_alignment(signal_score: float, mtf_alignment: float, cvd: float, bar_level: str) -> float:
    bar_weight = {"STRONG": 1.0, "MODERATE": 0.7, "WEAK": 0.3, "DEAD": 0.1}.get(bar_level, 0.5)
    sig_dir = 1.0 if signal_score > 0 else -1.0 if signal_score < 0 else 0.0
    mtf_dir = 1.0 if mtf_alignment > 0 else -1.0 if mtf_alignment < 0 else 0.0
    cvd_dir = 1.0 if cvd > 0.5 else -1.0 if cvd < 0.5 else 0.0
    alignment = (sig_dir * 0.35 + mtf_dir * 0.35 + cvd_dir * 0.15 + bar_weight * 0.15)
    return round(max(-1.0, min(1.0, alignment)), 3)


# ── Rollunder Recommendation ──────────────────────────────────────────────

def compute_rollunder(action: str, stability: str, risk_level: str) -> str:
    if action == "HOLD":
        return "HOLD"
    if stability == "LOW" or risk_level == "HIGH":
        return "HOLD"
    return "EXECUTE"


# ── Regime Classification (K-Synthesizer style) ─────────────────────────────

def compute_regime(mtf: dict, ind: dict, df: pd.DataFrame, trend_consistency: float) -> dict:
    """Classify market regime: direction+mode, decomposition, and volatility band.

    Approximates TCIP's regime/decomp_regime/volatility_regime using the MTF bias
    stack, trend consistency and normalized ATR — no external regime engine needed.
    """
    dirs = [mtf[k] for k in ("mtf_d1_dir", "mtf_h4_dir", "mtf_h1_dir", "mtf_m30_dir", "mtf_m15_dir")]
    bull = sum(1 for d in dirs if d == "BULLISH")
    bear = sum(1 for d in dirs if d == "BEARISH")
    align5 = (bull - bear) / len(dirs)

    price = 1.0
    if df is not None and len(df):
        price = float(df["Close"].iloc[-1]) or 1.0

    volatility_regime = "NORMAL"
    if df is not None and len(df) >= 20:
        tr = float((df["High"] - df["Low"]).tail(20).mean())
        pct = tr / price if price > 0 else 0.0
        if pct >= 0.012:
            volatility_regime = "HIGH"
        elif pct <= 0.004:
            volatility_regime = "LOW"

    split = trend_consistency - 0.5
    if abs(align5) >= 0.4 and abs(split) >= 0.12:
        decomp_regime = "TRENDING"
    else:
        decomp_regime = "RANGING"

    if decomp_regime == "RANGING" and abs(align5) < 0.2:
        regime = "RANGING"
    elif abs(align5) < 0.2:
        regime = "NEUTRAL"
    else:
        direction_label = "BULL" if align5 > 0 else "BEAR"
        energy = float(ind.get("macd", {}).get("histogram", 0.0)) / price if price > 0 else 0.0
        mode = "MOMENTUM" if abs(energy) >= 0.0008 else "TREND"
        regime = f"{direction_label} {mode}"

    return {
        "regime": regime,
        "decomp_regime": decomp_regime,
        "volatility_regime": volatility_regime,
        "regime_alignment": round(align5, 3),
    }


# ── Weaknesses (Devil's Advocate) ──────────────────────────────────────────

def compute_weaknesses(ind: dict, divergence: str, bar_level: str, stability: str,
                       cvd_eff: float, alignment: float, trend_consistency: float) -> list[str]:
    weaknesses = []
    if divergence != "NONE":
        weaknesses.append(f"{divergence} DIVERGENCE DETECTED")
    if bar_level in ("WEAK", "DEAD"):
        weaknesses.append(f"BAR LEVEL IS {bar_level}")
    if stability == "LOW":
        weaknesses.append("DIRECTION UNSTABLE — OSCILLATION RISK")
    if cvd_eff < 0.4:
        weaknesses.append("CVD FLOW NOT RELIABLE")
    if alignment < 0.6:
        weaknesses.append("LOW ALIGNMENT ACROSS FACTORS")
    if 0 < trend_consistency < 0.6:
        weaknesses.append(f"WHIPSAW PATTERN — TREND CONSISTENCY {trend_consistency * 100:.0f}%")
    return weaknesses


# ── Full Advanced Analysis ─────────────────────────────────────────────────

def analyze(df_1d: pd.DataFrame, ind: dict, signal: dict, prediction: dict,
            df_1h: pd.DataFrame | None = None, df_4h: pd.DataFrame | None = None,
            df_30m: pd.DataFrame | None = None, df_15m: pd.DataFrame | None = None,
            signal_history: list[str] | None = None) -> dict:
    """Run all advanced analyses and return a flat dict for the API response."""
    action = signal["action"]
    score = signal["score"]
    confidence = signal["confidence"]

    session_info = detect_session()
    mtf = compute_mtf(df_1d, df_1h, df_4h, df_30m, df_15m)
    grade = compute_grade(score, confidence, mtf["mtf_alignment"])
    stability = compute_stability(signal_history or [])
    divergence = detect_divergence(df_1d)
    bar_level = compute_bar_level(df_1d)
    trend_consistency = compute_trend_consistency(df_1d)
    cvd_eff = compute_cvd_efficiency(df_1d)
    smc_warning = detect_smc_warning(df_1d)
    tech_scores = compute_tech_scores(ind, score, prediction, mtf["mtf_alignment"])
    risk_level = compute_risk_level(confidence, stability, divergence, bar_level)
    alignment = compute_weighted_alignment(score, mtf["mtf_alignment"], cvd_eff, bar_level)
    weaknesses = compute_weaknesses(ind, divergence, bar_level, stability, cvd_eff, alignment, trend_consistency)
    rollunder = compute_rollunder(action, stability, risk_level)
    regime = compute_regime(mtf, ind, df_1d, trend_consistency)

    is_dead_zone = bar_level == "DEAD" or stability == "LOW"
    ml_rejected = confidence < 0.4

    return {
        "session": session_info["session"],
        "session_active": session_info["active_sessions"],
        **mtf,
        **regime,
        "grade": grade,
        "stability": stability,
        "divergence": divergence,
        "bar_level": bar_level,
        "trend_consistency_pct": round(trend_consistency * 100, 1),
        "cvd_efficiency": cvd_eff,
        "smc_warning": smc_warning,
        "risk_level": risk_level,
        "weighted_alignment": alignment,
        "roll_under_reco": rollunder,
        "weaknesses": weaknesses,
        "is_dead_zone": is_dead_zone,
        "ml_rejected": ml_rejected,
        **tech_scores,
    }
