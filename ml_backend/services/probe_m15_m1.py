"""Probe intraday M15/M1 via MT5 (data asli) - lengkapi hierarki bukti.

Param DIKUNCI = INTRADAY_PARAMS (swing 3, zona 6, SL 8, retest 24, RR 2.0).
Data disalin dulu ke research/data_xau_*.csv agar reproduksibel.
Tax-free krn riset; bukan jalur sinyal live.
"""
import os

import pandas as pd

from services.intraday_research import INTRADAY_PARAMS
from services.mt5_data import fetch_mt5, save_csv
from services.smc_limit_backtester import backtest_limit_entries

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _load_or_fetch(tf: str) -> pd.DataFrame:
    path = os.path.join(ROOT, "research", f"data_xau_{tf.lower()}.csv")
    if os.path.exists(path):
        df = pd.read_csv(path, index_col=0, parse_dates=True)
        if len(df) > 1000:
            return df
    df = fetch_mt5("XAUUSD", tf)
    save_csv(df, path)
    return df


def run(tf: str) -> dict:
    df = _load_or_fetch(tf)
    res = backtest_limit_entries(df, cost_r=0.0, **INTRADAY_PARAMS)
    res["_span"] = f"{df.index[0].date()} .. {df.index[-1].date()}"
    res["_bars"] = len(df)
    return res


def fmt(m: dict) -> str:
    if not m:
        return " -"
    return (f"bars={m.get('bars')} n={m.get('n')} fills={m.get('fills')} "
            f"win={m.get('win_rate')} PF={m.get('profit_factor')} "
            f"tp/sl={m.get('exits_tp')}/{m.get('exits_sl')}")


if __name__ == "__main__":
    for tf in ("M15", "M1"):
        r = run(tf)
        print(f"=== {tf} | span={r.get('_span')} bars={r.get('_bars')} ===")
        if not r.get("oos") and r.get("note"):
            print(" ", r.get("note"))
            continue
        print("  IS :", fmt(r.get("is")))
        print("  OOS:", fmt(r.get("oos")))