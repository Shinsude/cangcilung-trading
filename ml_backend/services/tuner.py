"""Auto-tune bobot sinyal per simbol.

Strategi: grid search multiplier grup (oscillator/trend/prediksi/sentimen)
terhadap data historis, memaksimalkan metrik kualitas backtest.
Hasil per simbol di-cache (in-memory) dengan TTL.
"""
import time

from services import backtest
from config import TUNE_TTL_SECONDS

_grid = (0.6, 1.0, 1.4)
_GROUP = ("oscillator", "trend", "prediction", "sentiment")

_tuned_cache: dict[str, dict] = {}  # symbol -> {"weights":..., "at": ts, "metrics":...}


def _weights_from(multipliers: dict) -> dict:
    m = {k: float(multipliers.get(g, 1.0)) for k, g in _group_map().items()}
    return m


def _group_map() -> dict:
    return {
        "rsi": "oscillator",
        "macd_cross": "oscillator",
        "macd_hist": "oscillator",
        "bb": "oscillator",
        "ema_trend": "trend",
        "ema_alignment": "trend",
        "prediction": "prediction",
        "sentiment": "sentiment",
    }


def _best_weights(df) -> dict:
    import itertools

    best = None
    best_q = -1.0
    best_mult = None
    combos = list(itertools.product(_grid, repeat=len(_GROUP)))

    for combo in combos:
        multipliers = dict(zip(_GROUP, combo))
        metrics = backtest.run(df, weights=_weights_from(multipliers))
        q = metrics["quality"]
        if q > best_q:
            best_q = q
            best = metrics
            best_mult = multipliers

    weights = _weights_from(best_mult)
    return {"weights": weights, "metrics": best, "multipliers": best_mult}


def tuned(df, symbol: str, force: bool = False, ttl: int | None = None) -> dict:
    now = time.time()
    hit = _tuned_cache.get(symbol)
    ttl = ttl or TUNE_TTL_SECONDS
    if hit and not force and (now - hit["at"] < ttl):
        return hit
    res = _best_weights(df)
    res["at"] = now
    res["symbol"] = symbol
    _tuned_cache[symbol] = res
    return res


def get_cached(symbol: str) -> dict | None:
    hit = _tuned_cache.get(symbol)
    if hit:
        return hit
    return None