"""Walk-forward backtest engine.

Menilai kualitas bobot sinyal terhadap data historis aktual.
Tidak melatih MLP (murah & cepat) — memakai proksi momentum untuk bagian
prediksi agar tuning/backtest bisa berjalan cepat di serverless.
"""
import numpy as np
import pandas as pd

from services.indicators import rsi, macd, bollinger, ema
from config import EMA_FAST, EMA_MEDIUM, EMA_SLOW, MACD_FAST, MACD_SIGNAL, MACD_SLOW, MIDDLE_BAND

COMPONENT_NAMES = ("rsi", "macd_cross", "macd_hist", "ema_trend", "ema_alignment", "bb", "prediction", "sentiment")


def _components(close: np.ndarray) -> dict:
    n = len(close)
    s = pd.Series(close)
    out = {k: np.zeros(n) for k in COMPONENT_NAMES}

    r = np.asarray(rsi(s), dtype=float)
    macd_line, macd_signal, macd_hist = macd(s)
    macd_hist = np.asarray(macd_hist, dtype=float)
    ema_f = np.asarray(ema(s, EMA_FAST), dtype=float)
    ema_m = np.asarray(ema(s, EMA_MEDIUM), dtype=float)
    ema_s = np.asarray(ema(s, EMA_SLOW), dtype=float)
    bb_upper, bb_mid, bb_lower = bollinger(s)
    bb_upper = np.asarray(bb_upper, dtype=float)
    bb_lower = np.asarray(bb_lower, dtype=float)

    fwd = np.full(n, np.nan)
    fwd[:-1] = np.diff(close) / close[:-1]

    safe = np.isfinite(r) & np.isfinite(macd_hist) & np.isfinite(bb_lower) & np.isfinite(fwd)
    for i in range(1, n):
        if not safe[i] or not safe[i - 1]:
            continue
        # RSI
        rv = r[i]
        if np.isnan(rv) or np.isinf(rv):
            pass
        elif rv < 30:
            out["rsi"][i] = 1.5
        elif rv > 70:
            out["rsi"][i] = -1.5
        elif 45 <= rv <= 55:
            out["rsi"][i] = 0.1
        # MACD: cross efektif mengikuti arah histogram (sama dgn signal.py live)
        mh, mh_prev = macd_hist[i], macd_hist[i - 1]
        if not np.isnan(mh) and not np.isnan(mh_prev):
            out["macd_hist"][i] = 0.8 if mh > 0 else -0.8
            out["macd_cross"][i] = 2.0 if mh > 0 else -2.0
        # EMA trend
        if not (np.isnan(ema_m[i]) or np.isnan(ema_s[i]) or np.isnan(ema_f[i])):
            out["ema_trend"][i] = 1.2 if close[i] > ema_m[i] else -1.2
            if ema_f[i] > ema_m[i] > ema_s[i]:
                out["ema_alignment"][i] = 0.8
            elif ema_f[i] < ema_m[i] < ema_s[i]:
                out["ema_alignment"][i] = -0.8
        # Bollinger
        if not (np.isnan(bb_lower[i]) or np.isnan(bb_upper[i])) and bb_upper[i] != bb_lower[i]:
            pctb = (close[i] - bb_lower[i]) / (bb_upper[i] - bb_lower[i])
            if pctb < 0.05:
                out["bb"][i] = 0.6
            elif pctb > 0.95:
                out["bb"][i] = -0.6
        # Prediksi proksi: momentum 5-bar
        if i >= 5:
            mom = close[i] / close[i - 5] - 1.0
            conf = min(0.95, abs(mom) * 10.0) if not np.isnan(mom) else 0.0
            out["prediction"][i] = (conf * 2.0 if mom > 0 else -conf * 2.0)
        # Sentimen proksi momentum 20-bar
        if i >= 20:
            mom20 = close[i] / close[i - 20] - 1.0
            if not np.isnan(mom20):
                out["sentiment"][i] = max(-1.0, min(1.0, mom20 * 12.0)) * 1.5
    return {k: v for k, v in out.items()}, fwd


def _tolist(a):
    a = np.asarray(a, dtype=float)
    a = a[np.isfinite(a)]
    return a.tolist()


def run(df: pd.DataFrame, weights: dict | None = None, buy_th: float = 1.5, strong_th: float = 3.0, hold_pct: float = 0.0) -> dict:
    close = np.asarray(df["Close"], dtype=float)
    comps, fwd = _components(close)
    wl = 1.0

    w = {
        "rsi": 1.0, "macd_cross": 1.0, "macd_hist": 1.0, "ema_trend": 1.0,
        "ema_alignment": 1.0, "bb": 1.0, "prediction": 1.0, "sentiment": 1.0,
    }
    if weights:
        for k in w:
            if k in weights and weights[k] is not None:
                w[k] = float(weights.get(k, 1.0))

    score = np.zeros(len(close))
    for k, mul in w.items():
        score += np.asarray(comps[k], dtype=float) * mul

    valid = np.isfinite(score) & np.isfinite(fwd)
    idx = np.where(valid)[0]

    eq = 1.0
    equity_curve = []
    trades = 0
    wins = 0
    gross_win = 0.0
    gross_loss = 0.0
    peak = 1.0
    max_dd = 0.0
    rets = []

    for i in idx:
        sc = score[i]
        ret = fwd[i]
        if sc >= buy_th:
            pos_ret = ret
            trades += 1
        elif sc <= -buy_th:
            pos_ret = -ret
            trades += 1
        elif hold_pct > 0 and abs(sc) >= hold_pct * buy_th:
            pos_ret = ret
            trades += 1
        else:
            pos_ret = 0.0
        if pos_ret > 0:
            wins += 1
            gross_win += pos_ret
        elif pos_ret < 0:
            gross_loss += -pos_ret
        eq *= 1.0 + pos_ret
        rets.append(pos_ret)
        peak = max(peak, eq)
        max_dd = max(max_dd, (peak - eq) / peak if peak else 0.0)
        equity_curve.append(eq)

    n = len(rets)
    total_return = eq - 1.0
    win_rate = (wins / trades) if trades else 0.0
    avg_win = (gross_win / wins) if wins else 0.0
    avg_loss = (gross_loss / (trades - wins)) if trades > wins else 0.0
    profit_factor = (gross_win / gross_loss) if gross_loss > 0 else (float("inf") if gross_win > 0 else 0.0)

    quality = win_rate + 0.5 * max(-0.2, min(0.5, total_return)) + 0.1 * min(1.0, trades / max(1, n))

    return {
        "quality": float(round(quality, 4)),
        "win_rate": float(round(win_rate, 4)),
        "profit_factor": float(profit_factor) if profit_factor != float("inf") else None,
        "total_return": float(round(total_return, 4)),
        "avg_win": float(round(avg_win, 6)),
        "avg_loss": float(round(avg_loss, 6)),
        "trades": int(trades),
        "bars": int(len(idx)),
        "max_drawdown": float(round(max_dd, 4)),
        "std_return": float(np.std(rets) if rets else 0.0),
    }