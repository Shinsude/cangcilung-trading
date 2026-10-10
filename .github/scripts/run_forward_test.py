"""Wrapper GitHub Actions: forward-test paper harian (yfinance, tanpa MT5).

Menjalankan pipeline paper forward-test pada runner Linux Ubuntu (tempat MT5
URL-terminal tidak tersedia). Log diperbarui (mengikuti isi log yang sudah ada),
lalu workflow melakukan commit.

Contoh:
    python3 .github/scripts/run_forward_test.py --interval 60m --period 2y \
        --log research/forward_test_log.csv
    python3 .github/scripts/run_forward_test.py --interval 30m --period 60d \
        --log research/forward_test_log_m30.csv
    python3 .github/scripts/run_forward_test.py --summary --log research/forward_test_log.csv
"""
import argparse
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "ml_backend"))

from services.forward_test import summary, update  # noqa: E402
from services.intraday_research import fetch_intraday  # noqa: E402

DEFAULT_LOG = os.path.join(ROOT, "research", "forward_test_log.csv")


def _log_path(raw: str) -> str:
    return raw if os.path.isabs(raw) else os.path.join(ROOT, raw)


def _fetch(interval: str, period: str, attempts: int = 3):
    """yfinance kadang balas kosong (throttle) -> coba beberapa kali."""
    for i in range(attempts):
        df = fetch_intraday(interval=interval, period=period)
        if df is not None and not df.empty:
            return df
        if i + 1 < attempts:
            time.sleep(10 * (i + 1))
    return None


def main() -> None:
    ap = argparse.ArgumentParser(description="paper forward-test harian (CI)")
    ap.add_argument("--interval", default="60m", help="interval yfinance: 60m / 30m")
    ap.add_argument("--period", default="2y", help="periode yfinance: 2y / 60d")
    ap.add_argument("--log", default=DEFAULT_LOG)
    ap.add_argument("--summary", action="store_true", help="cetak agregasi, jangan update")
    args = ap.parse_args()

    log_path = _log_path(args.log)
    if args.summary:
        print(f"ringkasan {os.path.relpath(log_path, ROOT)}: {summary(log_path=log_path)}")
        return

    df = _fetch(args.interval, args.period)
    if df is None or df.empty:
        print(f"forward-test: tidak ada data yfinance {args.interval}/{args.period}")
        return
    print("bars:", len(df), df.index[0], "->", df.index[-1])
    print(update(df, log_path=log_path))
    print(summary(log_path=log_path))


if __name__ == "__main__":
    main()
