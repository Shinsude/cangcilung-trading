"""Runner background: probe M15 & M1, tulis hasil ke research/probe_m15_m1_result.json.

Menulis inkremental: 'm15' setelah M15 selesai, 'm1' setelah M1 — supaya bisa
dipantau dari luar lewat mtime/isi file. stdout/stderr dialihkan ke file bila
PROBE_BG_LOG di-set (dipakai peluncuran detach WScript.Shell.Run).
"""
import json
import os
import sys

_log = os.environ.get("PROBE_BG_LOG")
if _log:
    sys.stdout = open(_log, "w", buffering=1)
    sys.stderr = sys.stdout

from services.probe_m15_m1 import run  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RESULT = os.path.join(ROOT, "research", "probe_m15_m1_result.json")


def _snapshot(tf: str, r: dict) -> dict:
    return {
        "tf": tf,
        "span": r.get("_span"),
        "bars": r.get("_bars"),
        "note": r.get("note"),
        "is": {"win": r.get("is", {}).get("win_rate"),
               "pf": r.get("is", {}).get("profit_factor"),
               "fills": r.get("is", {}).get("fill_rate"),
               "n": r.get("is", {}).get("filled"),
               "avg_r": r.get("is", {}).get("avg_r"),
               "exits": r.get("is", {}).get("exits")},
        "oos": {"win": r.get("oos", {}).get("win_rate"),
                "pf": r.get("oos", {}).get("profit_factor"),
                "fills": r.get("oos", {}).get("fill_rate"),
                "n": r.get("oos", {}).get("filled"),
                "avg_r": r.get("oos", {}).get("avg_r"),
                "exits": r.get("oos", {}).get("exits")},
    }


def main() -> None:
    out: dict = {}
    for tf in ("M15", "M1"):
        r = run(tf)
        out[tf] = _snapshot(tf, r)
        with open(RESULT, "w") as f:
            json.dump(out, f, indent=2)
        print(f"PROGRESS {tf} done", flush=True)
    print("DONE ALL", flush=True)


if __name__ == "__main__":
    main()