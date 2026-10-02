import time

import numpy as np
import pandas as pd

from services import tuner


def _df(n: int = 140) -> pd.DataFrame:
    rng = np.random.default_rng(7)
    closes = 4500 * np.exp(np.cumsum(rng.normal(0.0004, 0.012, n)))
    df = pd.DataFrame(
        {
            "Open": closes,
            "High": closes * 1.003,
            "Low": closes * 0.997,
            "Close": closes,
            "Volume": rng.integers(1_000_000, 8_000_000, n),
        }
    )
    df.index = pd.date_range(end=pd.Timestamp.now().normalize(), periods=n, freq="D")
    return df


def test_tuned_first_call_blocking():
    res = tuner.tuned(_df(), "PERF_SYM_A")
    assert res["weights"]
    assert res["symbol"] == "PERF_SYM_A"
    assert res["metrics"]["quality"] > 0


def test_tuned_expired_serves_stale_then_refreshes():
    df = _df()
    tuner.tuned(df, "PERF_SYM_B")
    at_old = tuner._tuned_cache["PERF_SYM_B"]["at"]
    tuner._tuned_cache["PERF_SYM_B"]["at"] = time.time() - 10**6  # paksa kedaluwarsa

    stale = tuner.tuned(df, "PERF_SYM_B")
    assert stale["at"] == tuner._tuned_cache["PERF_SYM_B"]["at"]  # balasan sync = versi lama

    deadline = time.time() + 30
    while time.time() < deadline:
        if tuner.tuned(df, "PERF_SYM_B")["at"] != at_old:
            return
        time.sleep(0.1)
    raise AssertionError("cache tuning tidak disegarkan oleh thread background")