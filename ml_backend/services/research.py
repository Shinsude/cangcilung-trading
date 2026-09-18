"""Research backtests: transparansi performa sinyal dengan biaya transaksi
realistis, aturan entry disiplin, perbandingan per rezim pasar, dan uji
sensitivitas ambang (threshold). Deterministik, tanpa network.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from services.backtest import compute_scores, run
from services.market_analysis import _regime_label, _rolling_efficiency

COST_PCT_DEFAULT = 0.0005  # 0,05% biaya tiap arah posisi
REGIME_WINDOW = 30


def _eval_rets(rets: list[float], cost_pct: float) -> dict:
    """Hitung metrik klasik dari daftar return posisi (biasanya non-zero)."""
    eq = 1.0
    wins = 0
    gross_win = 0.0
    gross_loss = 0.0
    peak = 1.0
    max_dd = 0.0
    for r in rets:
        r = r - cost_pct
        if abs(r) <= 0:
            continue
        if r > 0:
            wins += 1
            gross_win += r
        else:
            gross_loss += -r
        eq *= 1.0 + r
        peak = max(peak, eq)
        max_dd = max(max_dd, (peak - eq) / peak if peak else 0.0)
    trades = len(rets)
    return {
        "trades": int(trades),
        "win_rate": round(wins / trades, 4) if trades else 0.0,
        "total_return": round(eq - 1.0, 4),
        "max_drawdown": round(max_dd, 4),
        "profit_factor": round(gross_win / gross_loss, 4) if gross_loss > 0 else (None if gross_win > 0 else 0.0),
    }


def strict_run(df: pd.DataFrame, weights: dict | None = None, buy_th: float = 1.5, cost_pct: float = COST_PCT_DEFAULT) -> dict:
    """Kembalikan sinyal yang baru menyilang ambang (fresh-cross) tiap harinya."""
    close = np.asarray(df["Close"], dtype=float)
    score, fwd = compute_scores(close, weights, df)
    valid = np.where(np.isfinite(score) & np.isfinite(fwd))[0]
    rets: list[float] = []
    for pos in range(1, len(valid)):
        i = valid[pos]
        i_prev = valid[pos - 1]
        s, sp = score[i], score[i_prev]
        r = fwd[i]
        if s >= buy_th < sp:
            rets.append(r)
        elif s <= -buy_th > sp:
            rets.append(-r)
    return _eval_rets(rets, cost_pct)


def regime_breakdown(df: pd.DataFrame, weights: dict | None = None, buy_th: float = 1.5,
                     cost_pct: float = COST_PCT_DEFAULT, window: int = REGIME_WINDOW) -> list[dict]:
    """Win-rate/return per rezim pasar (TRENDING_UP, TRENDING_DOWN, TEKANAN, PELEMAHAN, CHOPPY)."""
    close = np.asarray(df["Close"], dtype=float)
    score, fwd = compute_scores(close, weights, df)
    valid = np.where(np.isfinite(score) & np.isfinite(fwd))[0]
    buckets: dict[str, list[float]] = {}
    for i in valid:
        if i < window:
            continue
        eff = _rolling_efficiency(close, i, window)
        net = float(close[i] - close[i - window])
        label = _regime_label(eff, net)
        s = score[i]
        r = fwd[i]
        if s >= buy_th:
            buckets.setdefault(label, []).append(r)
        elif s <= -buy_th:
            buckets.setdefault(label, []).append(-r)
    out = []
    for label, rets in sorted(buckets.items()):
        m = _eval_rets(rets, cost_pct)
        m["regime"] = label
        m["samples"] = int(len(rets))
        out.append(m)
    return out


def current_regime(df: pd.DataFrame, window: int = REGIME_WINDOW) -> dict:
    """Rezim label untuk bar terakhir — merekatkan riset historis ke kondisi pasar sekarang."""
    close = np.asarray(df["Close"], dtype=float)
    i = len(close) - 1
    eff = _rolling_efficiency(close, i, window)
    net = float(close[i] - close[i - window]) if i >= window else 0.0
    return {"label": _regime_label(eff, net), "efficiency": round(eff, 3)}


def sensitivity(df: pd.DataFrame, weights: dict | None = None, thresholds=(1.2, 1.5, 1.8, 2.1, 2.4)) -> list[dict]:
    """Uji sensitivitas ambang sinyal terhadap performa (tanpa biaya)."""
    out = []
    for th in thresholds:
        m = run(df, weights=weights, buy_th=th)
        out.append({
            "buy_th": float(th),
            "trades": m["trades"],
            "win_rate": m["win_rate"],
            "total_return": m["total_return"],
            "max_drawdown": m["max_drawdown"],
            "quality": m["quality"],
        })
    return out


def summary(df: pd.DataFrame, weights: dict | None = None, cost_pct: float = COST_PCT_DEFAULT) -> dict:
    """Ringkasan riset lengkap untuk endpoint /research/{symbol}."""
    strict = strict_run(df, weights=weights, cost_pct=cost_pct)
    relaxed = run(df, weights=weights)

    net_effect = round(strict["total_return"], 4) - round(relaxed["total_return"], 4)
    win_delta = round(strict["win_rate"], 4) - round(relaxed["win_rate"], 4)
    trade_delta = strict["trades"] - relaxed["trades"]

    regime = current_regime(df)
    rows = regime_breakdown(df, weights=weights, cost_pct=cost_pct)
    for row in rows:
        row["is_current"] = row["regime"] == regime["label"] and row["samples"] > 0

    return {
        "data_points": int(len(df)),
        "current_regime": regime,
        "cost_model": {
            "cost_pct": cost_pct,
            "rule": "Setiap sinyal baru menyilang ambang (fresh-cross) dikenai biaya 0,05% sekali jalan.",
        },
        "relaxed": {
            "trades": relaxed["trades"],
            "win_rate": relaxed["win_rate"],
            "total_return": relaxed["total_return"],
            "max_drawdown": relaxed["max_drawdown"],
            "profit_factor": relaxed["profit_factor"],
        },
        "strict": strict,
        "difference": {
            "win_rate": win_delta,
            "total_return": net_effect,
            "trades": trade_delta,
            "note": "Selisih negatif = disiplin ketat (fresh-cross + biaya) lebih realistis, angka relaxed cenderung optimistis.",
        },
        "by_regime": rows,
        "sensitivity": sensitivity(df, weights=weights),
    }