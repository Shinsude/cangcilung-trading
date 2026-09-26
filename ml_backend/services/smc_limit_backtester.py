"""Limit-order (pending) backtester for SMC zones.

This module answers the execution question the geometry-only backtests in
``smc_backtester`` deliberately avoid: *"if I rest a limit order inside a zone
instead of market-buying at the open of the next bar, does the hypothesis
Choch + Premium/Discount hold up under real fills?"*

Rules (no peeking):

1. A ChoCh (change of character) is detected from swing structure:
   - BULL: the most recent swing low made a lower low vs the swing low before
     it (sell-side grab), and the bar closes above the last swing high.
   - BEAR: the most recent swing high made a higher high vs the swing high
     before it (buy-side grab), and the bar closes below the last swing low.
2. The nearest FVG of the same direction that is still in discount/premium
   territory (below price for a buy, above price for a sell) is marked as a
   pending limit order. Entry = 50% (equilibrium) of that zone.
3. The order fills if price retraces into the zone within ``retest_lookahead``
   bars. Stop-loss = the last swing extreme; take-profit = RR * risk.
4. Same-bar SL/TP is settled conservatively (stop first -> loss).

The module is timeframe-agnostic (works on daily proxies or M30/M5 if such
data is supplied). Parameters live in one place so In-Sample tuning and
Out-of-Sample confirmation can be reported side by side.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from services.smc_backtester import collect_fvg_signals

SWING_P = 3                # bars counted each side of a swing extreme
ZONE_AGE_BARS = 60         # max bars between the ChoCh and the zone candle
SL_BARS = 20               # bars scanned back from the signal for the SL extreme
RETEST_LOOKAHEAD = 10      # bars allowed for the limit to be filled
RR = 2.0                   # take-profit = RR * risk
ENTRY_PCT = 0.5            # equilibrium = 50% of the zone
MIN_BARS = 80


def _bars(df):
    return {
        "open": df["Open"].astype(float).to_numpy(),
        "high": df["High"].astype(float).to_numpy(),
        "low": df["Low"].astype(float).to_numpy(),
        "close": df["Close"].astype(float).to_numpy(),
    }


def _swing_masks(b: dict, p: int = SWING_P):
    n = len(b["high"])
    is_sh = np.zeros(n, dtype=bool)
    is_sl = np.zeros(n, dtype=bool)
    for i in range(p, n - p):
        left_h = b["high"][i - p : i]
        right_h = b["high"][i + 1 : i + p + 1]
        if b["high"][i] > max(left_h.max(), right_h.max()):
            is_sh[i] = True
        left_l = b["low"][i - p : i]
        right_l = b["low"][i + 1 : i + p + 1]
        if b["low"][i] < min(left_l.min(), right_l.min()):
            is_sl[i] = True
    return is_sh, is_sl


def _last_idx(mask: np.ndarray, upto: int) -> int | None:
    idx = mask[:upto]
    hits = np.nonzero(idx)[0]
    return int(hits[-1]) if hits.size else None


def detect_choch(df, p: int = SWING_P) -> list[dict]:
    """Every Change-of-Character printed anywhere in the series.

    BULL at bar ``i``: the last swing low (SL2) is lower than the swing low
    before it (SL1) — a sell-side grab — and close[i] closes back above the
    swing high printed before SL2 (SH1). BEAR is the mirror.
    """
    if df is None or len(df) < MIN_BARS:
        return []
    b = _bars(df)
    is_sh, is_sl = _swing_masks(b, p)
    n = len(b["close"])
    out = []
    for i in range(p + 2, n):
        sl2 = _last_idx(is_sl, i)              # grab low (before i)
        if sl2 is not None:
            sh1 = _last_idx(is_sh, sl2)        # swing high before the grab
            sl1 = _last_idx(is_sl, sh1)        # swing low before that high
            if sh1 is not None and sl1 is not None:
                if b["low"][sl2] < b["low"][sl1] and b["close"][i] > b["high"][sh1]:
                    out.append(
                        {"index": i, "direction": "BULL", "swing_high": int(sh1), "swing_low": int(sl2)}
                    )
                    continue
        sh2 = _last_idx(is_sh, i)              # grab high (before i)
        if sh2 is not None:
            sl1b = _last_idx(is_sl, sh2)       # swing low before the grab
            sh0 = _last_idx(is_sh, sl1b)       # swing high before that low
            if sl1b is not None and sh0 is not None:
                if b["high"][sh2] > b["high"][sh0] and b["close"][i] < b["low"][sl1b]:
                    out.append(
                        {"index": i, "direction": "BEAR", "swing_high": int(sh2), "swing_low": int(sl1b)}
                    )
    return out


def nearest_zone(df, choch: dict, age_bars: int = ZONE_AGE_BARS, entry_pct: float = ENTRY_PCT):
    """Nearest same-direction FVG in discount/premium territory under the signal.

    For a BUY we need the gap fully below the signal close (premium stays
    untested above; the retrace enters our discount). Distance is measured in
    bars (freshness), then, among candidates within ``age_bars``, the highest
    top (BUY) / lowest bottom (SELL) is chosen. Returns the pending order or
    None.
    """
    if df is None or len(df) < 2:
        return None
    b = _bars(df)
    px = float(b["close"][choch["index"]])
    sig_lo = max(0, choch["index"] - age_bars)
    cands = [
        s
        for s in collect_fvg_signals(df)
        if s["type"] == choch["direction"] and sig_lo <= s["index"] < choch["index"]
    ]
    if choch["direction"] == "BULL":
        cands = [c for c in cands if c["top"] <= px]
        if not cands:
            return None
        z = max(cands, key=lambda c: c["top"])  # nearest below price
    else:
        cands = [c for c in cands if c["bottom"] >= px]
        if not cands:
            return None
        z = min(cands, key=lambda c: c["bottom"])  # nearest above price
    entry = z["bottom"] + entry_pct * (z["top"] - z["bottom"])
    return {
        "zone_index": int(z["index"]),
        "top": float(z["top"]),
        "bottom": float(z["bottom"]),
        "entry": float(entry),
    }


def _sl_level(b: dict, sig_index: int, direction: str, sl_bars: int = SL_BARS):
    lo = max(0, sig_index - sl_bars)
    seg_lo = b["low"][lo : sig_index + 1]
    seg_hi = b["high"][lo : sig_index + 1]
    if direction == "BULL":
        return float(seg_lo.min())
    return float(seg_hi.max())


def simulate_limit(df, choch: dict, zone: dict, rr: float = RR, lookahead: int = RETEST_LOOKAHEAD,
                   sl_bars: int = SL_BARS):
    """Fill the pending order forward; return PnL in R-multiples (or None)."""
    b = _bars(df)
    n = len(b["close"])
    direction = choch["direction"]
    entry = zone["entry"]
    sig = choch["index"]
    if sig + 1 >= n:
        return {"filled": False, "r": None, "bars_to_fill": None, "exit": "no_future"}
    if direction == "BULL":
        sl = _sl_level(b, sig, "BULL", sl_bars=sl_bars)
        tp = entry + rr * (entry - sl)
    else:
        sl = _sl_level(b, sig, "BEAR", sl_bars=sl_bars)
        tp = entry - rr * (sl - entry)
    risk = abs(entry - sl)
    if risk <= 0:
        return {"filled": False, "r": None, "bars_to_fill": None, "exit": "zero_risk"}

    fill_j = None
    for j in range(sig + 1, min(sig + 1 + lookahead, n)):
        if direction == "BULL" and b["low"][j] <= entry:
            fill_j = j
            break
        if direction == "BEAR" and b["high"][j] >= entry:
            fill_j = j
            break
    if fill_j is None:
        return {"filled": False, "r": None, "bars_to_fill": None, "exit": "not_filled"}

    end = min(fill_j, n - 1)
    for j in range(fill_j, min(fill_j + 1 + lookahead, n)):
        if direction == "BULL":
            if b["low"][j] <= sl:  # stop first (conservative)
                return {"filled": True, "r": -1.0, "bars_to_fill": int(fill_j - sig), "exit": "stop"}
            if b["high"][j] >= tp:
                return {"filled": True, "r": float(rr), "bars_to_fill": int(fill_j - sig), "exit": "target"}
        else:
            if b["high"][j] >= sl:
                return {"filled": True, "r": -1.0, "bars_to_fill": int(fill_j - sig), "exit": "stop"}
            if b["low"][j] <= tp:
                return {"filled": True, "r": float(rr), "bars_to_fill": int(fill_j - sig), "exit": "target"}
        end = j
    # timeout: exit at the last evaluated bar's close
    final = float(b["close"][end]) if end < n else float(b["close"][n - 1])
    if direction == "BULL":
        return {"filled": True, "r": round((final - entry) / risk, 4), "bars_to_fill": int(fill_j - sig), "exit": "timeout"}
    return {"filled": True, "r": round((entry - final) / risk, 4), "bars_to_fill": int(fill_j - sig), "exit": "timeout"}


def _net_r(trade: dict, cost_r: float) -> float:
    if not trade["filled"] or trade["r"] is None:
        return 0.0
    return float(trade["r"] - cost_r)


def _summary(trades: list[dict], cost_r: float = 0.0) -> dict:
    filled = [t for t in trades if t["filled"]]
    total = len(trades)
    n_fill = len(filled)
    net = [_net_r(t, cost_r) for t in filled]
    wins = [r for r in net if r > 0]
    losses = [r for r in net if r <= 0]
    gross_profit = sum(r for r in net if r > 0)
    gross_loss = sum(-r for r in net if r < 0)
    return {
        "signals": total,
        "filled": n_fill,
        "fill_rate": round(n_fill / total * 100, 1) if total else 0.0,
        "wins": len(wins),
        "losses": len(losses),
        "win_rate": round(len(wins) / n_fill * 100, 1) if n_fill else 0.0,
        "gross_profit_r": round(gross_profit, 3),
        "gross_loss_r": round(gross_loss, 3),
        "profit_factor": round(gross_profit / gross_loss, 3) if gross_loss > 0 else (None if gross_profit > 0 else 0.0),
        "avg_r": round(sum(net) / n_fill, 3) if n_fill else 0.0,
        "exits": {k: sum(1 for t in filled if t["exit"] == k) for k in ("target", "timeout", "stop", "no_future", "zero_risk")},
    }


def _slice(df, start, end):
    if start is None and end is None:
        return df
    d = df.iloc[: len(df)]
    if start is not None:
        d = d.loc[d.index >= start]
    if end is not None:
        d = d.loc[d.index <= end]
    return d


def _run_slice(df: pd.DataFrame, **params) -> dict:
    chochs = detect_choch(df, p=params["swing_p"])
    trades = []
    for c in chochs:
        z = nearest_zone(df, c, age_bars=params["zone_age_bars"])
        if z is None:
            trades.append({"filled": False, "r": None, "exit": "no_zone"})
            continue
        trades.append(
            simulate_limit(
                df, c, z,
                rr=params["rr"],
                lookahead=params["retest_lookahead"],
                sl_bars=params["sl_bars"],
            )
        )
    return _summary(trades, cost_r=params.get("cost_r", 0.0))


def backtest_limit_entries(
    df,
    is_start=None,
    is_end=None,
    oos_start=None,
    oos_end=None,
    swing_p: int = SWING_P,
    zone_age_bars: int = ZONE_AGE_BARS,
    retest_lookahead: int = RETEST_LOOKAHEAD,
    rr: float = RR,
    sl_bars: int = SL_BARS,
    cost_r: float = 0.0,
) -> dict:
    """In-Sample vs Out-of-Sample limit-order backtest.

    ``cost_r``: biaya tetap per trade yang tertinggal (spread + slippage +
    komisi) dalam satuan R; ``0.0`` = bruto (lihat catatan di bawah). Biaya
    dipotong dari setiap trade yang tertutup sebelum agregasi.

    Slices accept anything ``df.index >= start`` supports (Timestamp strings
    for intraday/daily, or ints for positional splits). When the OOS range is
    omitted the dataframe is split 60/40 by index (IS first, OOS after).
    """
    if df is None or len(df) < MIN_BARS:
        return {"note": "insufficient data", "bars": 0}
    params = {
        "swing_p": swing_p,
        "zone_age_bars": zone_age_bars,
        "retest_lookahead": retest_lookahead,
        "rr": rr,
        "sl_bars": sl_bars,
        "cost_r": cost_r,
    }
    if oos_start is None and oos_end is None and is_start is None and is_end is None:
        split = int(len(df) * 0.6)
        is_df = df.iloc[:split]
        oos_df = df.iloc[split:]
    else:
        is_df = _slice(df, is_start, is_end)
        oos_df = _slice(df, oos_start, oos_end)
    is_sum = _run_slice(is_df, **params)
    oos_sum = _run_slice(oos_df, **params)
    return {
        "bars": int(len(df)),
        "params": params,
        "is": is_sum,
        "oos": oos_sum,
        "note": (
            "WARNING: pada data harian, perlakukan angka ini sebagai alur kerja — bukan alpha final. "
            "Validasi statistik yang jujur butuh konfirmasi OOS bahwa PF/win-rate IS tidak runtuh. "
            "R dihitung dalam satuan risk (R=1 = satu SL)."
        ),
    }