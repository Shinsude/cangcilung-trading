"""Wrapper GitHub Actions: forward-test 60m harian (yfinance saja, tanpa MT5).

Menjalankan pipeline paper forward-test pada runner Linux Ubuntu (tempat MT5
URL-terminal tidak tersedia). Log diperbarui di research/forward_test_log.csv
(mengikuti seed pertama yang sudah ada), lalu workflow melakukan commit.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "ml_backend"))

from services.forward_test import update  # noqa: E402
from services.intraday_research import fetch_intraday  # noqa: E402

LOG_PATH = os.path.join(ROOT, "research", "forward_test_log.csv")


def main() -> None:
    df = fetch_intraday(interval="60m", period="2y")
    if df is None or df.empty:
        print("forward-test: tidak ada data yfinance 60m")
        return
    print("bars:", len(df), df.index[0], "->", df.index[-1])
    print(update(df, log_path=LOG_PATH))


if __name__ == "__main__":
    main()