"""Walk-forward backtest engine.

Menilai kualitas bobot sinyal terhadap data historis aktual.
Tidak melatih MLP (murah & cepat) — memakai proksi momentum untuk bagian
prediksi agar tuning/backtest bisa berjalan cepat di serverless.
"""
import numpy as np
import pandas as pd

from services.indicators import rsi, macd, bollinger, ema
from config import EMA_FAST, EMA_MEDIUM, EMA_SLOW, MACD_FAST, MACD_SIGNAL, MACD_SLOW, MIDDLE_BAND

COMPONENT_NAMES = ("rsi", "macd_cross", "macd_hist", "ema_trend", "ema_alignment", "bb", "prediction", "sentiment", "volume", "sr")


def _components(close: np.ndarray, df=None) -> dict:
    n = len(close)
    s = pd.Series(close)
    out = {k: np.zeros(n) for k in COMPONENT_NAMES}

    high = np.asarray(df["High"], dtype=float) if df is not None else close
    low = np.asarray(df["Low"], dtype=float) if df is not None else close
    vol = np.asarray(df["Volume"], dtype=float) if df is not None and "Volume" in df else np.ones(n)

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
    # Sentimen proksi momentum 20-bar
        if i >= 20:
            mom20 = close[i] / close[i - 20] - 1.0
            if not np.isnan(mom20):
                out["sentiment"][i] = max(-1.0, min(1.0, mom20 * 12.0)) * 1.5
        # Komponen volume:kekuatan konfirmasi tren (naik dgn volume tinggi = bullish)
        if i >= 20:
            v20 = vol[i - 20 : i + 1]
            vmean = float(np.mean(v20))
            atr = float(np.mean(high[i - 14 : i + 1] - low[i - 14 : i + 1])) if i >= 14 else 0.0
            direction = 1.0 if close[i] > close[i - 1] else -1.0
            vol_conf = (vol[i] / vmean - 1.0) if vmean > 0 else 0.0
            out["volume"][i] = direction * 0.8 * (1.0 + vol_conf) if np.isfinite(vol_conf) and vol[i] > 0 else 0.0
        # S/R momentum: posisi harga terhadap range 20-bar terakhir
        if i >= 20:
            hi20 = float(np.max(high[i - 20 : i + 1]))
            lo20 = float(np.min(low[i - 20 : i + 1]))
            if hi20 != lo20:
                pos = (close[i] - lo20) / (hi20 - lo20)
                out["sr"][i] = 1.0 if pos > 0.8 else (-1.0 if pos < 0.2 else 0.0)
    return {k: v for k, v in out.items()}, fwd


def _tolist(a):
    a = np.asarray(a, dtype=float)
    a = a[np.isfinite(a)]
    return a.tolist()


def compute_scores(close: np.ndarray, weights: dict | None = None, df=None) -> tuple[np.ndarray, np.ndarray]:
    comps, fwd = _components(close, df)
    w = {
        "rsi": 1.0, "macd_cross": 1.0, "macd_hist": 1.0, "ema_trend": 1.0,
        "ema_alignment": 1.0, "bb": 1.0, "prediction": 1.0, "sentiment": 1.0,
        "volume": 1.0, "sr": 1.0,
    }
    if weights:
        for k in w:
            if weights.get(k) is not None:
                w[k] = float(weights[k])
    score = np.zeros(len(close))
    for k, mul in w.items():
        score += np.asarray(comps[k], dtype=float) * mul
    return score, fwd


def _evaluate(score: np.ndarray, fwd: np.ndarray, buy_th: float, idx: list) -> dict:
    eq = 1.0
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
        pos_ret = ret if sc >= buy_th else (-ret if sc <= -buy_th else 0.0)
        if pos_ret > 0:
            wins += 1
            gross_win += pos_ret
        elif pos_ret < 0:
            gross_loss += -pos_ret
        if abs(pos_ret) > 0:
            trades += 1
        eq *= 1.0 + pos_ret
        rets.append(pos_ret)
        peak = max(peak, eq)
        max_dd = max(max_dd, (peak - eq) / peak if peak else 0.0)
    n = len(rets)
    return {
        "win_rate": float(round(wins / trades, 4)) if trades else 0.0,
        "trades": int(trades),
        "bars": int(n),
        "total_return": float(round(eq - 1.0, 4)),
        "profit_factor": float(gross_win / gross_loss) if gross_loss > 0 else (None if gross_win > 0 else None),
        "avg_win": float(round(gross_win / wins, 6)) if wins else 0.0,
        "avg_loss": float(round(gross_loss / (trades - wins), 6)) if trades > wins else 0.0,
        "max_drawdown": float(round(max_dd, 4)),
        "std_return": float(round(float(np.std(rets)), 6)) if rets else 0.0,
    }


def rolling(close: np.ndarray, weights: dict | None = None, windows=(7, 14, 30), buy_th: float = 1.5, skip: int = 0, df=None) -> dict:
    score, fwd = compute_scores(close, weights, df)
    valid = np.where(np.isfinite(score) & np.isfinite(fwd))[0]
    out = {}
    for wnd in windows:
        tail = [i for i in valid if i >= len(close) - wnd - skip and i < len(close) - skip]
        m = _evaluate(score, fwd, buy_th, tail)
        m["window"] = int(wnd)
        out[f"{wnd}d"] = m
    return out


def run(df: pd.DataFrame, weights: dict | None = None, buy_th: float = 1.5, strong_th: float = 3.0, hold_pct: float = 0.0) -> dict:
    close = np.asarray(df["Close"], dtype=float)
    score, fwd = compute_scores(close, weights, df)
    valid = np.where(np.isfinite(score) & np.isfinite(fwd))[0]
    idx = valid.tolist()

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