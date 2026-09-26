"""Paper forward-test 60m/M30 — pencatatan sinyal, bukan eksekusi live.

Pola jujur:
- setap run mengambil data terbaru (MT5 M30/H1, fallback yfinance 60m),
- hitung sinyal choch+zone sekali, simpan ``signal_time -> outcome``,
- sinyal BARU (signal_time > yang sudah di-log) ditulis sebagai pending
  ``found_at`` = waktu run,
- baris pending yang sudah lewat window retrace+exit di-resolusi memakai data
  yang SUDAH terjadi (tanpa lookahead — resolusi hanya di run berikutnya).

Cara pakai:
    py -m services.forward_test --source mt5_m30     # default 60m via yfinance
    py -m services.forward_test --seed               # seed log dengan jendela terbaru
Log ditulis ke research/forward_test_log.csv.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import pandas as pd

from services.intraday_research import INTRADAY_PARAMS, fetch_intraday
from services.mt5_data import fetch_mt5
from services.smc_limit_backtester import _bars, _sl_level, detect_choch, nearest_zone, simulate_limit

DEFAULT_LOG = str(Path(__file__).resolve().parents[2] / "research" / "forward_test_log.csv")
CSV_COLUMNS = [
    "signal_time", "zone_time", "direction", "entry", "sl", "tp", "rr",
    "found_at", "status", "resolved_at", "r",
]

PARAMS = dict(INTRADAY_PARAMS)


def build_records(df: pd.DataFrame) -> list[dict]:
    """Semua sinyal choch+zone tertutup lengkap dengan level eksekusinya."""
    if df is None or len(df) < 80:
        return []
    b = _bars(df)
    recs = []
    for c in detect_choch(df, p=PARAMS["swing_p"]):
        z = nearest_zone(df, c, age_bars=PARAMS["zone_age_bars"])
        if z is None:
            continue
        direction = "BUY" if c["direction"] == "BULL" else "SELL"
        entry = float(z["entry"])
        sl = _sl_level(b, c["index"], c["direction"], sl_bars=PARAMS["sl_bars"])
        risk = entry - sl if direction == "BUY" else sl - entry
        if risk <= 0:
            continue
        tp = entry + PARAMS["rr"] * risk if direction == "BUY" else entry - PARAMS["rr"] * risk
        recs.append(
            {
                "signal_time": str(df.index[c["index"]]),
                "zone_time": str(df.index[z["zone_index"]]),
                "direction": direction,
                "entry": round(entry, 2),
                "sl": round(sl, 2),
                "tp": round(tp, 2),
                "rr": PARAMS["rr"],
                "sig": c,
                "zone": z,
            }
        )
    return recs


def outcomes_map(df: pd.DataFrame, recs: list[dict]) -> dict[str, dict]:
    out = {}
    for r in recs:
        o = simulate_limit(df, r["sig"], r["zone"], rr=PARAMS["rr"],
                           lookahead=PARAMS["retest_lookahead"], sl_bars=PARAMS["sl_bars"])
        out[r["signal_time"]] = o
    return out


def _status_from(o: dict) -> tuple[str, float | None]:
    if not o["filled"]:
        if o["exit"] == "not_filled":
            return "no_fill", None
        return "pending", None
    if o["exit"] == "target":
        return "target", o["r"]
    if o["exit"] == "stop":
        return "stop", o["r"]
    return "timeout", o["r"]


def load_log(path: str) -> pd.DataFrame:
    if not os.path.exists(path):
        return pd.DataFrame(columns=CSV_COLUMNS)
    log = pd.read_csv(path, parse_dates=["signal_time", "found_at", "resolved_at"])
    return log


def update(df: pd.DataFrame, log_path: str = DEFAULT_LOG, seed: bool = False) -> dict:
    """Perbarui log: tulis sinyal baru, resolusi yang sudah lewat window."""
    recs = build_records(df)
    log = load_log(log_path)
    now = pd.Timestamp.now().normalize()
    last_bar = df.index[-1]
    lookahead = PARAMS["retest_lookahead"]

    existing = set(log["signal_time"].astype(str)) if not log.empty else set()
    outcome = outcomes_map(df, recs)

    rows = []
    if not log.empty:
        rows = log.to_dict("records")

    lookahead = PARAMS["retest_lookahead"]
    if seed:
        cutoff = df.index[max(0, len(df) - 1 - 2 * lookahead)]
    elif existing:
        cutoff = pd.Timestamp(str(log["signal_time"].max()))
    else:
        cutoff = df.index[max(0, len(df) - 1 - lookahead)]

    for r in recs:
        st = pd.Timestamp(r["signal_time"])
        if st > cutoff and st not in existing:
            rows.append(
                {
                    "signal_time": r["signal_time"],
                    "zone_time": r["zone_time"],
                    "direction": r["direction"],
                    "entry": r["entry"],
                    "sl": r["sl"],
                    "tp": r["tp"],
                    "rr": PARAMS["rr"],
                    "found_at": now,
                    "status": "pending",
                    "resolved_at": pd.NaT,
                    "r": None,
                }
            )

    for row in rows:
        if row["status"] != "pending":
            continue
        st = pd.Timestamp(row["signal_time"])
        sig_pos = int(df.index.searchsorted(st, side="left"))
        if sig_pos + lookahead >= len(df):
            continue
        o = outcome.get(row["signal_time"])
        if o is None:
            continue
        status, r = _status_from(o)
        if status == "pending":
            continue
        row["status"] = status
        row["resolved_at"] = now
        row["r"] = r

    out = pd.DataFrame(rows, columns=CSV_COLUMNS)
    out.to_csv(log_path, index=False, date_format="%Y-%m-%d %H:%M:%S")
    resolved = (out["status"] != "pending").sum()
    return {
        "rows": int(len(out)),
        "new": len(out.index) - (len(log.index) if not log.empty else 0),
        "resolved": int(resolved - (0 if log.empty else (log["status"] != "pending").sum())),
        "pending": int((out["status"] == "pending").sum()),
        "log_path": log_path,
    }


def _load_source(src: str) -> pd.DataFrame | None:
    if src == "mt5_m30":
        return fetch_mt5("XAUUSD", "M30", start="2024-01-01")
    if src == "mt5_h1":
        return fetch_mt5("XAUUSD", "H1", start="2024-09-01")
    return fetch_intraday(interval="60m", period="2y")


def main() -> None:
    ap = argparse.ArgumentParser(description="paper forward-test SMC (60m/M30)")
    ap.add_argument("--source", default="yf_60m", choices=["yf_60m", "mt5_m30", "mt5_h1"])
    ap.add_argument("--seed", action="store_true", help="log jendela terbaru pertama kali")
    ap.add_argument("--log", default=DEFAULT_LOG)
    args = ap.parse_args()

    df = _load_source(args.source)
    if df is None or df.empty:
        print("tidak ada data untuk source", args.source)
        return
    print("bars:", len(df), df.index[0], "->", df.index[-1])
    res = update(df, log_path=args.log, seed=args.seed)
    print(res)


if __name__ == "__main__":
    main()