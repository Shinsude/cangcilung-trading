"""Ambil sinyal harian dari backend dan tambahkan ke flutter_app/web/signals_log.json.

Dipanggil oleh GitHub Actions (scheduler harian). File JSON ikut artefak web sehingga
backend /stats dapat membaca riwayat sinyal nyata dan mengevaluasi akurasi terhadap
close hari berikutnya tanpa database.
"""
import datetime
import json
import os
import urllib.request

BASE = "https://cangcilung-trading-api.vercel.app/signal/"
PATH = os.path.join("flutter_app", "web", "signals_log.json")
SYMBOLS = ("XAUUSD", "NASDAQ", "AUDUSD")


def load() -> list:
    if os.path.exists(PATH):
        with open(PATH, encoding="utf-8") as f:
            return json.load(f)
    return []


def fetch(symbol: str) -> dict:
    with urllib.request.urlopen(BASE + symbol, timeout=180) as r:
        d = json.load(r)
    sig = d["signal"]
    return {
        "date": datetime.datetime.utcnow().strftime("%Y-%m-%d"),
        "symbol": symbol,
        "action": sig["action"],
        "strength": sig["strength"],
        "score": sig["score"],
        "close": d["current_price"],
    }


def main() -> None:
    today = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    data = load()
    for s in SYMBOLS:
        if any(e.get("symbol") == s and e.get("date") == today for e in data):
            print(f"skip {s}: sudah tercatat hari ini")
            continue
        try:
            data.append(fetch(s))
        except Exception as exc:  # noqa: BLE001
            print(f"skip {s}: {exc}")
    if not os.path.isdir(os.path.dirname(PATH)):
        os.makedirs(os.path.dirname(PATH), exist_ok=True)
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"total entri: {len(data)}")


if __name__ == "__main__":
    main()