"""Statistical backtests for the daily SMC proxies.

These do NOT test tick execution. They measure the geometric probability
that a price-level story (FVG, liquidity sweep, order block) actually played
out over a short forward window in the daily yfinance series, so we can
decide (with numbers, not vibes) whether the labels we ship to the app
carry predictive value or are just visual noise.

Outputs are dicts of plain floats/ints so callers can render tables,
write JSON, or gate the live signal off the measured rates.
"""
import numpy as np
import pandas as pd

FVG_LOOKAHEAD = 10           # bars to decide "was the FVG mitigated / did it react"
SWEEP_LOOKAHEAD = 5          # bars to decide "was the sweep a reversal"
OB_LOOKAHEAD = 10            # bars to decide "did the order block hold"
OB_SCAN_BACK = 8             # max bars before the FVG to look for the trigger candle
OB_VOLUME_MULT = 1.2         # candidate OB candle volume threshold vs its 20d average
REACTION_PCT = 0.01          # +1% advance after FVG mitigation = successful reaction
SWEEP_REVERSAL_PCT = 0.015   # +1.5% (+/-, per side) after sweep = successful reversal
MIN_BARS = 35                # below this we refuse to compute anything meaningful


def _bars(df):
    return {
        "open": df["Open"].astype(float).to_numpy(),
        "high": df["High"].astype(float).to_numpy(),
        "low": df["Low"].astype(float).to_numpy(),
        "close": df["Close"].astype(float).to_numpy(),
        "volume": df["Volume"].astype(float).to_numpy() if "Volume" in df else np.zeros(len(df)),
    }


def collect_fvg_signals(df) -> list[dict]:
    """Every FVG printed anywhere in the series (not just the last one)."""
    if df is None or len(df) < 20:
        return []
    b = _bars(df)
    n = len(b["high"])
    sigs = []
    for i in range(2, n - 1):
        if b["low"][i] > b["high"][i - 2]:
            sigs.append(
                {
                    "index": i,
                    "type": "BULL",
                    "top": float(b["low"][i]),
                    "bottom": float(b["high"][i - 2]),
                }
            )
        if b["high"][i] < b["low"][i - 2]:
            sigs.append(
                {
                    "index": i,
                    "type": "BEAR",
                    "top": float(b["low"][i - 2]),
                    "bottom": float(b["high"][i]),
                }
            )
    return sigs


def collect_sweep_signals(df) -> list[dict]:
    """Liquidity sweeps of the previous session's PDH (sell) / PDL (buy)."""
    if df is None or len(df) < 2:
        return []
    b = _bars(df)
    n = len(b["high"])
    sigs = []
    for i in range(1, n):
        prev_high = b["high"][i - 1]
        prev_low = b["low"][i - 1]
        if (
            b["high"][i] > prev_high
            and b["close"][i] < prev_high  # poked above, closed back inside
        ):
            sigs.append(
                {"index": i, "type": "SELL_SWEEP", "level": float(prev_high), "close": float(b["close"][i])}
            )
        if (
            b["low"][i] < prev_low
            and b["close"][i] > prev_low  # poked below, closed back inside
        ):
            sigs.append(
                {"index": i, "type": "BUY_SWEEP", "level": float(prev_low), "close": float(b["close"][i])}
            )
    return sigs


def collect_order_block_signals(df) -> list[dict]:
    """Trigger candle behind each FVG: last opposite candle within OB_SCAN_BACK."""
    if df is None or len(df) < 20:
        return []
    b = _bars(df)

    def vol_sma20(idx: int) -> float:
        lo = max(0, idx - 19)
        return float(b["volume"][lo : idx + 1].mean())

    sigs = []
    for fvg_sig in collect_fvg_signals(df):
        i = fvg_sig["index"]
        for j in range(i - 1, max(0, i - 1 - OB_SCAN_BACK), -1):
            if fvg_sig["type"] == "BULL" and b["close"][j] < b["open"][j]:
                sigs.append(
                    {
                        "index": j,
                        "type": "BULL",
                        "top": float(b["high"][j]),
                        "bottom": float(b["low"][j]),
                        "volume": float(b["volume"][j]),
                        "vol_sma20": vol_sma20(j),
                    }
                )
                break
            if fvg_sig["type"] == "BEAR" and b["close"][j] > b["open"][j]:
                sigs.append(
                    {
                        "index": j,
                        "type": "BEAR",
                        "top": float(b["high"][j]),
                        "bottom": float(b["low"][j]),
                        "volume": float(b["volume"][j]),
                        "vol_sma20": vol_sma20(j),
                    }
                )
                break
    return sigs


def _window_hl(df, start: int, lookahead: int):
    end = min(start + lookahead, len(df))
    if end <= start:
        return (np.array([]), np.array([]))
    seg = df.iloc[start:end]
    return (
        seg["High"].astype(float).to_numpy(),
        seg["Low"].astype(float).to_numpy(),
    )


def backtest_fvg(df, lookahead: int = FVG_LOOKAHEAD, reaction_pct: float = REACTION_PCT) -> dict:
    """How often an FVG gets touched (mitigation) and then bounces (reaction)."""
    if df is None or len(df) < MIN_BARS:
        return {
            "count": 0,
            "mitigated": 0,
            "reacted": 0,
            "mitigation_rate": 0.0,
            "reaction_rate": 0.0,
            "avg_bullish_zone_pct": 0.0,
            "note": "insufficient data",
        }

    b = _bars(df)
    total_zone_pct = 0.0
    mitigated = 0
    reacted = 0
    signals = collect_fvg_signals(df)

    for sig in signals:
        idx = sig["index"]
        hi, lo = _window_hl(df, idx + 1, lookahead)
        if hi.size == 0:
            continue
        zone_size = sig["top"] - sig["bottom"]
        if zone_size > 0:
            total_zone_pct += zone_size / b["close"][idx] * 100.0

        touched = False
        if sig["type"] == "BULL":
            touched = bool(lo.min() <= sig["top"])  # price re-entered the gap
            reaction_ok = touched and bool(hi.max() >= sig["top"] * (1 + reaction_pct))
        else:
            touched = bool(hi.max() >= sig["bottom"])  # price re-entered the gap
            reaction_ok = touched and bool(lo.min() <= sig["bottom"] * (1 - reaction_pct))

        if touched:
            mitigated += 1
            if reaction_ok:
                reacted += 1

    count = len(signals)
    return {
        "count": count,
        "mitigated": mitigated,
        "reacted": reacted,
        "mitigation_rate": round(mitigated / count * 100, 1) if count else 0.0,
        "reaction_rate": round(reacted / mitigated * 100, 1) if mitigated else 0.0,
        "avg_bullish_zone_pct": round(total_zone_pct / count, 2) if count else 0.0,
        "note": None,
    }


def backtest_sweep(df, lookahead: int = SWEEP_LOOKAHEAD, reversal_pct: float = SWEEP_REVERSAL_PCT) -> dict:
    """How often a PDH/PDL sweep reverses instead of continuing as a breakout."""
    if df is None or len(df) < MIN_BARS:
        return {
            "count": 0,
            "reversals": 0,
            "reversal_rate": 0.0,
            "by_type": {"BUY_SWEEP": {"count": 0, "reversals": 0}, "SELL_SWEEP": {"count": 0, "reversals": 0}},
            "note": "insufficient data",
        }

    signals = collect_sweep_signals(df)
    by_type = {"BUY_SWEEP": {"count": 0, "reversals": 0}, "SELL_SWEEP": {"count": 0, "reversals": 0}}
    total_reversals = 0

    for sig in signals:
        t = sig["type"]
        by_type[t]["count"] += 1
        hi, lo = _window_hl(df, sig["index"] + 1, lookahead)
        if hi.size == 0:
            continue
        if t == "BUY_SWEEP":
            # anticipated: price reclaimed the PDL and pushes higher
            ok = bool(hi.max() >= sig["close"] * (1 + reversal_pct))
        else:
            # anticipated: price failed the PDH break and pushes lower
            ok = bool(lo.min() <= sig["close"] * (1 - reversal_pct))
        if ok:
            by_type[t]["reversals"] += 1
            total_reversals += 1

    count = len(signals)
    helper = {
        t: {
            "count": by_type[t]["count"],
            "reversals": by_type[t]["reversals"],
            "reversal_rate": round(by_type[t]["reversals"] / by_type[t]["count"] * 100, 1)
            if by_type[t]["count"]
            else 0.0,
        }
        for t in ("BUY_SWEEP", "SELL_SWEEP")
    }
    return {
        "count": count,
        "reversals": total_reversals,
        "reversal_rate": round(total_reversals / count * 100, 1) if count else 0.0,
        "by_type": helper,
        "note": None,
    }


def backtest_order_blocks(
    df,
    lookahead: int = OB_LOOKAHEAD,
    volume_mult: float = OB_VOLUME_MULT,
) -> dict:
    """Hold rate of order blocks, split by trigger-candle volume strength.

    A block "holds" when price does not close past the far edge of the zone
    within the forward window. We count the same rule for all blocks (A) and
    only for blocks whose trigger candle had > volume_mult x its 20d average
    volume (B). If B >> A, the volume filter earns its keep.
    """
    if df is None or len(df) < MIN_BARS:
        return {
            "all": {"count": 0, "held": 0, "hold_rate": 0.0},
            "volume_filtered": {"count": 0, "held": 0, "hold_rate": 0.0},
            "note": "insufficient data",
        }

    keep = []
    held_all = 0
    held_vol = 0
    collected = collect_order_block_signals(df)

    for sig in collected:
        hi, lo = _window_hl(df, sig["index"] + 1, lookahead)
        if hi.size == 0:
            continue
        if sig["type"] == "BULL":
            holds = bool((lo > sig["bottom"]).all())  # never broke the demand floor
        else:
            holds = bool((hi < sig["top"]).all())  # never broke the supply roof
        keep.append(holds)
        if holds:
            held_all += 1
            if sig["vol_sma20"] > 0 and sig["volume"] >= volume_mult * sig["vol_sma20"]:
                held_vol += 1

    all_count = len(keep)
    vol_count = sum(
        1 for s in collected if s["vol_sma20"] > 0 and s["volume"] >= volume_mult * s["vol_sma20"]
    )
    return {
        "all": {
            "count": all_count,
            "held": held_all,
            "hold_rate": round(held_all / all_count * 100, 1) if all_count else 0.0,
        },
        "volume_filtered": {
            "count": vol_count,
            "held": held_vol,
            "hold_rate": round(held_vol / vol_count * 100, 1) if vol_count else 0.0,
        },
        "note": None,
    }


def backtest_summary(df) -> dict:
    """One call, all metrics, with short plain-language decision hints."""
    f = backtest_fvg(df)
    s = backtest_sweep(df)
    ob = backtest_order_blocks(df)

    ob_a = ob["all"]["hold_rate"]
    ob_b = ob["volume_filtered"]["hold_rate"]
    if ob["volume_filtered"]["count"]:
        ob_gap = round(ob_b - ob_a, 1)
        ob_verdict = (
            "volume filter has positive edge"
            if ob_gap >= 10
            else "volume filter shows no material edge" if ob_gap >= -5 else "volume filter hurts"
        )
    else:
        ob_gap = 0.0
        ob_verdict = "no volume-filtered samples"

    return {
        "bars": len(df) if df is not None else 0,
        "handlers": {
            "fvg": f,
            "sweep": s,
            "order_blocks": ob,
        },
        "decisions": {
            "fvg_mitigation_rate": f["mitigation_rate"],
            "fvg_reaction_rate": f["reaction_rate"],
            "sweep_reversal_rate": s["reversal_rate"],
            "ob_hold_rate_all": ob_a,
            "ob_hold_rate_volume": ob_b,
            "ob_volume_gap_pp": ob_gap,
            "ob_volume_verdict": ob_verdict,
        },
    }