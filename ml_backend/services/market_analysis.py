"""Market structure analysis: regime, volatility, momentum, divergence,
price levels, and a plain-language "Baca Pasar" explanation.

Pure pandas/numpy — dipakai di endpoint /signal sebagai field top-level
`market` tanpa mengubah perhitungan action/confidence sinyal yang sudah ada.
Semua fungsi dijamin deterministik terhadap data yang sama.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

import services.indicators as indicators

REGIME_EFF_TREND = 0.35
REGIME_EFF_MIXED = 0.18
VOL_HIGH_RATIO = 1.35
VOL_LOW_RATIO = 0.65
ATR_SL_MULT = 1.5
ATR_TP1_MULT = 1.5
ATR_TP2_MULT = 2.5


# ── Bantu: pivot & klaster level ────────────────────────────────────────────

def _pivot_indices(values: pd.Series, order: int = 3, top: bool = True) -> list[int]:
    """Indeks swing high/low lokal (pivot) berjarak minimal `order` bar."""
    arr = values.to_numpy(dtype=float)
    piv = []
    for i in range(order, len(arr) - order):
        win = arr[i - order: i + order + 1]
        if top:
            if arr[i] == win.max() and arr[i] > arr[i - 1] and arr[i] > arr[i + 1]:
                piv.append(i)
        else:
            if arr[i] == win.min() and arr[i] < arr[i - 1] and arr[i] < arr[i + 1]:
                piv.append(i)
    return piv


def _cluster_levels(values: list[float], tol: float, price: float, max_items: int = 3) -> list[float]:
    """Gabungkan level berdekatan (dalam `tol`) lalu ambil yang paling dekat ke `price`."""
    if not values:
        return []
    vals = sorted(float(v) for v in values)
    groups: list[list[float]] = []
    for v in vals:
        if groups and v - groups[-1][-1] <= tol:
            groups[-1].append(v)
        else:
            groups.append([v])
    means = [float(np.mean(g)) for g in groups]
    means.sort(key=lambda x: abs(x - price))
    return means[:max_items]


def _rolling_efficiency(closes: np.ndarray, i: int, window: int) -> float:
    """Kaufman efficiency ratio pada window berakhir di index i (0..1)."""
    if i < window:
        return 0.0
    seg = closes[i - window + 1: i + 1]
    path = float(np.sum(np.abs(np.diff(seg))))
    if path <= 0:
        return 0.0
    return float(abs(seg[-1] - seg[0]) / path)


def _regime_label(eff: float, net: float) -> str:
    if eff >= REGIME_EFF_TREND:
        return "TRENDING_UP" if net > 0 else "TRENDING_DOWN"
    if eff >= REGIME_EFF_MIXED:
        return "TEKANAN" if net > 0 else "PELEMAHAN"
    return "CHOPPY"


def _regime_note(label: str, eff: float) -> str:
    if label == "TRENDING_UP":
        return f"Pasar bergerak naik dengan teratur (efisiensi {eff:.0%}). Uptrend cenderung berlanjut selama harga bertahan di atas support terdekat."
    if label == "TRENDING_DOWN":
        return f"Pasar bergerak turun dengan teratur (efisiensi {eff:.0%}). Downtrend cenderung berlanjut selama harga tertahan di bawah resistance terdekat."
    if label == "TEKANAN":
        return "Tren lemah dengan bias naik — arah belum konsisten, tunggu konfirmasi breakout."
    if label == "PELEMAHAN":
        return "Tren lemah dengan bias turun — arah belum konsisten, tunggu konfirmasi breakdown."
    return "Pasar bergerak acak/sideways (gorak-gorok). Risiko false signal lebih tinggi; kurangi frekuensi trading atau tunggu breakout kisaran."


# ── Blok analisis ───────────────────────────────────────────────────────────

def _analyze_regime(closes: np.ndarray, window: int = 20) -> dict:
    n = len(closes)
    if n < window + 1:
        return {"label": "CHOPPY", "efficiency": 0.0, "consistency": 0.5, "note": _regime_note("CHOPPY", 0.0)}
    eff = _rolling_efficiency(closes, n - 1, window)
    net = float(closes[-1] - closes[-window])
    label = _regime_label(eff, net)
    changes = np.diff(closes[-window:])
    ups = float(np.sum(changes > 0)) / len(changes) if len(changes) else 0.5
    return {"label": label, "efficiency": round(eff, 3), "consistency": round(ups, 3), "note": _regime_note(label, eff)}


def _analyze_volatility(closes: np.ndarray, atr: float, price: float) -> dict:
    atr_pct = (atr / price * 100.0) if price and atr else 0.0
    state = "NORMAL"
    ratio = None
    rets = np.diff(np.log(np.maximum(closes, 1e-9)))
    if len(rets) >= 40:
        base = float(np.std(rets[-40:-10])) if len(rets) >= 10 else 0.0
        recent = float(np.std(rets[-10:]))
        if base > 0:
            ratio = float(recent / base)
            if ratio >= VOL_HIGH_RATIO:
                state = "HIGH"
            elif ratio <= VOL_LOW_RATIO:
                state = "LOW"
    return {"state": state, "atr_pct": round(atr_pct, 3), "ratio": round(ratio, 3) if ratio is not None else None}


def _analyze_momentum(closes: np.ndarray) -> dict:
    n = len(closes)
    if n < 21:
        return {"roc_5": 0.0, "roc_20": 0.0, "direction": "NEUTRAL", "bulk": "FLAT"}
    roc5 = float(closes[-1] / closes[-6] - 1.0)
    roc20 = float(closes[-1] / closes[-21] - 1.0)
    direction = "NEUTRAL"
    if roc20 > 0.002:
        direction = "UP"
    elif roc20 < -0.002:
        direction = "DOWN"
    bulk = "FLAT"
    if roc5 * roc20 > 0 and abs(roc5) > abs(roc20) * 1.1:
        bulk = "ACCELERASI"
    elif roc5 * roc20 > 0 and abs(roc5) < abs(roc20) * 0.9:
        bulk = "PERLAMBATAN"
    elif roc5 * roc20 <= 0 and abs(roc20) > 0.003:
        bulk = "MEMBALIK"
    return {"roc_5": round(roc5, 4), "roc_20": round(roc20, 4), "direction": direction, "bulk": bulk}


def _analyze_divergence(closes: pd.Series, rsi: pd.Series, macd_hist: pd.Series) -> dict:
    if len(closes) < 24:
        return {"rsi": "NONE", "macd": "NONE", "note": ""}
    lows_c = _pivot_indices(closes, order=3, top=False)
    highs_c = _pivot_indices(closes, order=3, top=True)

    rsi_div, macd_div = "NONE", "NONE"
    if len(lows_c) >= 2:
        a, b = lows_c[-2], lows_c[-1]
        if closes.iloc[b] < closes.iloc[a] and rsi.iloc[b] > rsi.iloc[a]:
            rsi_div = "BULLISH"
        if closes.iloc[b] < closes.iloc[a] and macd_hist.iloc[b] > macd_hist.iloc[a]:
            macd_div = "BULLISH"
    if len(highs_c) >= 2:
        a, b = highs_c[-2], highs_c[-1]
        if closes.iloc[b] > closes.iloc[a] and rsi.iloc[b] < rsi.iloc[a]:
            rsi_div = "BEARISH"
        if closes.iloc[b] > closes.iloc[a] and macd_hist.iloc[b] < macd_hist.iloc[a]:
            macd_div = "BEARISH"
    if rsi_div != "NONE" and rsi_div == macd_div:
        note = (
            f"Divergensi {rsi_div.lower()} ganda (RSI & MACD) terhadap harga — "
            "momentum bertentangan dengan arah pergerakan harga."
        )
    elif rsi_div != "NONE":
        note = f"Divergensi RSI {rsi_div.lower()} terhadap harga — momentum lemah untuk melanjutkan arah."
    elif macd_div != "NONE":
        note = f"Divergensi MACD {macd_div.lower()} terhadap harga — tekanan arah sedang berubah."
    else:
        note = ""
    return {"rsi": rsi_div, "macd": macd_div, "note": note}


def _analyze_levels(df: pd.DataFrame, price: float, atr: float, decimals: int) -> dict:
    tail = df.tail(60)
    highs = tail["High"].astype(float)
    lows = tail["Low"].astype(float)
    closes = tail["Close"].astype(float)

    piv_h = [float(highs.iloc[i]) for i in _pivot_indices(highs, order=3, top=True)]
    piv_l = [float(lows.iloc[i]) for i in _pivot_indices(lows, order=3, top=False)]
    piv_h.append(float(highs.max(axis=0)))
    piv_l.append(float(lows.min(axis=0)))

    tol = max(atr * 0.3, 1e-9)
    supports = _cluster_levels([v for v in piv_l if v < price * 0.999], tol, price)
    resistances = _cluster_levels([v for v in piv_h if v > price * 1.001], tol, price)
    supports.sort(reverse=True)
    resistances.sort()

    nearest_support = float(supports[0]) if supports else None
    nearest_resistance = float(resistances[0]) if resistances else None

    pivot = float((highs.iloc[-1] + lows.iloc[-1] + closes.iloc[-1]) / 3.0)

    def _r(x: float | None):
        return round(float(x), decimals) if x is not None else None

    return {
        "pivot": _r(pivot),
        "support": [_r(v) for v in supports],
        "resistance": [_r(v) for v in resistances],
        "nearest_support": _r(nearest_support),
        "nearest_resistance": _r(nearest_resistance),
        "distance_to_support_pct": round((price - nearest_support) / price * 100.0, 3) if nearest_support else None,
        "distance_to_resistance_pct": round((nearest_resistance - price) / price * 100.0, 3) if nearest_resistance else None,
    }


def _analyze_confirmation(ind: dict, roc20_dir: str, signal_action: str) -> dict:
    rsi_zone = 1 if ind["rsi"]["value"] > 50 else (-1 if ind["rsi"]["value"] < 50 else 0)
    macd_dir = 1 if ind["macd"]["histogram"] > 0 else (-1 if ind["macd"]["histogram"] < 0 else 0)
    ema_dir = 1 if ind["ema"]["trend"] == "bullish" else (-1 if ind["ema"]["trend"] == "bearish" else 0)
    bb_dir = 1 if (ind["bollinger"].get("percent_b") or 0.5) > 0.5 else (-1 if (ind["bollinger"].get("percent_b") or 0.5) < 0.5 else 0)
    mom_dir = 1 if roc20_dir == "UP" else (-1 if roc20_dir == "DOWN" else 0)
    vol_dir = 1 if ind.get("volume", 0) > 0 else (-1 if ind.get("volume", 0) < 0 else 0)

    items = [
        {"label": "Tren EMA", "direction": _dir_name(ema_dir)},
        {"label": "MACD histogram", "direction": _dir_name(macd_dir)},
        {"label": "Indeks RSI", "direction": _dir_name(rsi_zone)},
        {"label": "Bollinger %B", "direction": _dir_name(bb_dir)},
        {"label": "Momentum 20 hari", "direction": _dir_name(mom_dir)},
        {"label": "Tekanan volume", "direction": _dir_name(vol_dir)},
    ]

    if signal_action == "BUY":
        bias = 1
    elif signal_action == "SELL":
        bias = -1
    else:
        bias = 0

    if bias == 0:
        seq = [it["direction"] for it in items]
        ups = sum(1 for d in seq if d == "UP")
        downs = sum(1 for d in seq if d == "DOWN")
        bias = 1 if ups > downs else (-1 if downs > ups else 0)

    def _sign(d: str) -> int:
        return 1 if d == "UP" else (-1 if d == "DOWN" else 0)

    for it in items:
        s = _sign(it["direction"])
        it["agree"] = (s != 0) and (s == bias)

    total = max(1, sum(1 for it in items if it["direction"] != "NEUTRAL"))
    agreeing = sum(1 for it in items if it["agree"])
    return {
        "bias": _dir_name(bias),
        "total": int(total),
        "agreeing": int(agreeing),
        "concurrence": round(agreeing / total, 3),
        "items": items,
    }


def _dir_name(s: int) -> str:
    return "UP" if s > 0 else ("DOWN" if s < 0 else "NEUTRAL")


def _plan_exits(side: str, price: float, atr: float, decimals: int) -> dict:
    if side not in ("BUY", "SELL") or atr <= 0:
        return {"side": None, "sl": None, "tp1": None, "tp2": None, "risk_reward": None}
    direction = 1.0 if side == "BUY" else -1.0
    sl = price - direction * ATR_SL_MULT * atr
    tp1 = price + direction * ATR_TP1_MULT * atr
    tp2 = price + direction * ATR_TP2_MULT * atr
    risk = abs(price - sl)
    rr1 = (abs(tp1 - price) / risk) if risk > 0 else None
    rr2 = (abs(tp2 - price) / risk) if risk > 0 else None

    def _r(x):
        return round(float(x), decimals)

    return {
        "side": side,
        "sl": _r(sl),
        "tp1": _r(tp1),
        "tp2": _r(tp2),
        "risk_reward": round(rr1, 2) if rr1 is not None else None,
        "risk_reward_tp2": round(rr2, 2) if rr2 is not None else None,
    }


def _build_explain(market: dict, levels: dict, momentum: dict, divergence: dict, volatility: dict, confirm: dict, signal_action: str, price: float, decimals: int) -> list[str]:
    out = [market["note"]]

    if levels["nearest_support"] is not None or levels["nearest_resistance"] is not None:
        bits = []
        if levels["nearest_support"] is not None:
            bits.append(f"support terdekat {levels['nearest_support']} (jarak {levels['distance_to_support_pct']}%)")
        if levels["nearest_resistance"] is not None:
            bits.append(f"resistance terdekat {levels['nearest_resistance']} (jarak {levels['distance_to_resistance_pct']}%)")
        out.append(f"Harga saat ini {round(price, decimals)} — " + " dan ".join(bits) + ".")

    if momentum["direction"] != "NEUTRAL":
        if momentum["bulk"] == "MEMBALIK":
            out.append(f"Momentum 20 hari {momentum['direction']} tapi sedang membalik ({momentum['roc_20']:+.2%}) — waspada perubahan arah.")
        elif momentum["bulk"] in ("ACCELERASI", "PERLAMBATAN"):
            out.append(f"Momentum 20 hari {momentum['direction']} ({momentum['roc_20']:+.2%}) dengan {momentum['bulk'].lower()}.")
        else:
            out.append(f"Momentum 20 hari {momentum['direction']} ({momentum['roc_20']:+.2%}).")
    else:
        out.append("Momentum 20 hari datar — belum ada dorongan arah yang dominan.")

    vmap = {
        "HIGH": "Aktivitas harga meningkat (volatilitas tinggi) — stop loss perlu lebih longgar, ukuran posisi lebih kecil.",
        "LOW": "Aktivitas harga menurun (volatilitas rendah) — pasar tenang, gerakan cenderung kecil.",
        "NORMAL": "Volatilitas normal.",
    }
    out.append(vmap.get(volatility["state"], vmap["NORMAL"]))

    if divergence["note"]:
        out.append(divergence["note"])

    if signal_action == "BUY":
        out.append(f"Sinyal BUY didukung {confirm['agreeing']}/{confirm['total']} konfirmasi teknis (kebulatan {confirm['concurrence']:.0%}).")
    elif signal_action == "SELL":
        out.append(f"Sinyal SELL didukung {confirm['agreeing']}/{confirm['total']} konfirmasi teknis (kebulatan {confirm['concurrence']:.0%}).")
    else:
        out.append("Tidak ada bias dominan — sinyal HOLD. Harga belum meyakinkan untuk masuk posisi.")

    out.append("Analisis deskriptif dari data harian, bukan saran trading.")
    return out


# ── API utama ───────────────────────────────────────────────────────────────

def analyze_market(df: pd.DataFrame, ind: dict, signal: dict, decimals: int = 2, window: int = 20) -> dict:
    """Analisis struktur pasar untuk payload /signal (field `market`)."""
    if df is None or len(df) < 30:
        return {
            "available": False,
            "regime": {"label": "CHOPPY", "efficiency": 0.0, "consistency": 0.5, "note": "Data historis terlalu sedikit untuk analisis struktur."},
            "explain": [],
        }

    closes_s = df["Close"].astype(float)
    closes = closes_s.to_numpy(dtype=float)
    price = float(closes[-1])
    atr = float(ind.get("atr") or 0.0)

    rsi_s = indicators.rsi(closes_s)
    macd_line, macd_sig, macd_hist_s = indicators.macd(closes_s)

    regime = _analyze_regime(closes, window)
    volatility = _analyze_volatility(closes, atr, price)
    momentum = _analyze_momentum(closes)
    divergence = _analyze_divergence(closes_s, rsi_s, macd_hist_s)
    levels = _analyze_levels(df, price, atr, decimals)

    action = signal.get("action", "HOLD")
    confirm = _analyze_confirmation(ind, momentum["direction"], action)
    exits = _plan_exits(action, price, atr, decimals)

    explain = _build_explain(regime, levels, momentum, divergence, volatility, confirm, action, price, decimals)

    return {
        "available": True,
        "decimals": decimals,
        "regime": regime,
        "volatility": volatility,
        "momentum": momentum,
        "divergence": divergence,
        "confirmations": confirm,
        "levels": levels,
        "plan": exits,
        "explain": explain,
    }