# 01 — Baseline SMC Falsification Log

> Prinsip: kode kami harus dikalahkan oleh data sebelum kami percaya padanya.
> File ini mengubur hipotesis yang gagal dan mencatat *mengapa* ia gagal, agar 6 bulan
> dari sekarang kami tidak menebak-nebak lagi.

## 1. Hipotesis awal

Setup SMC harian (`GC=F`, proxy daily — bukan order-flow intraday) memiliki edge positif:

- **FVG** (Fair Value Gap) yang pernah disentuh cenderung memantul (**reaction**).
- **Sweep** PDH/PDL cenderung **reversal** (bukan breakout lanjutan).
- **Order Block** dengan volume kuat cenderung **hold** (tidak ditembus).

## 2. Metode uji

Modul `ml_backend/services/smc_backtester.py` mengukur **probabilitas geometri harga**
atas window maju pendek (FVG/SWEEP/OB masing-masing 5-10 bar) di 1258 bar harian
`GC=F` (2021-09-27 -> 2026-09-25):

- FVG: "ter-mitigasi" = harga masuk kembali ke gap; "reaction" = setelah mitigasi melaju >=1%.
- Sweep: "reversal" = dalam 5 bar harga bergerak >=1.5% melawan arah sweep.
- OB: "hold" = harga *tidak* menembus tepi jauh zona dalam 10 bar.
- Bias skor *live* hanya menghitung sweep yang ter-**CONFIRMED** oleh bar berikutnya.

> **Kejujuran metrik**: ini **bukan** backtest eksekusi (tanpa slippage, tanpa SL/TP,
> tanpa biaya). Membaca "reaction rate" sebagai profit berarti menipu diri sendiri —
> lihat catatan bias di section 4.

## 3. Hasil (diukur, bukan diklaim)

| Hipotesis | Metrik | Hasil 5y | Putusan |
|---|---|---|---|
| FVG puntulan | mitigation | 76.9% (299 sinyal) | OK terkonfirmasi sebagai *geometri* |
| FVG reaction | reaction-rate | 90.0% | WARNING **bias** (lihat section 4) |
| Sweep reversal | raw reversal-rate | **48.2%** (606) | GAGAL **= koin** |
| Sweep + konfirmasi 1 bar | confirmed reversal | **85.3%** (102) | OK **edge aktual** (BUY 92.3%, SELL 78.0%) |
| OB volume >=1.2x SMA20 | hold-rate | 47.1% -> 52.5% (+5.4pp) | WARNING **no material edge** (verdict mesin) |

## 4. Kesimpulan — The "Why"

1. **Sweep mentah (48.2%) membuktikan bahwa "sweep alone" tidak punya edge.**
   Hampir separuh sweep berakhir sebagai breakout, bukan reversal. Setup sweep sebagai
   sinyal langsung tanpa filter adalah **falsifikasi murni**. Ini yang kami ubah di v1.6.1:
   sekarang sweep baru dianggap sinyal jika bar berikutnya menutup tegas melampaui
   ekstremnya (gate `CONFIRMED`) — dan reversal-rate naik ke 85.3% (n=102).

2. **"Reaction 90%" adalah angka yang menyesatkan.**
   Reaction-rate dihitung *hanya dari sinyal yang sudah ter-mitigasi duluan* (rate kumulatif
   = 76.9% * 90% = ~69% dari semua FVG). Ia juga memakai jendela *lookahead* penuh —
   artinya mengukur "apakah harga *pernah* memantul", bukan "apakah entry di open bar
   berikutnya profit". **Ia tidak boleh dibaca sebagai profit rate atau alpha.** Inilah jenis
   bias yang biasanya dijual sebagai bukti; di repo ini ia di-label "geometri", bukan "edge".

3. **OB volume-filter (+5.4pp, ~20% sampel) tidak layak dipakai sebagai filter wajib.**
   Verdict mesin: *"volume filter shows no material edge"*. Volume >=1.2x SMA20 dipakai
   hanya sebagai **prioritas/preferensi** ketika beberapa OB bersaing — bukan sebagai
   gate. Klaim bahwa "volume filter = edge" adalah **falsifikasi**.

4. **Falsifikasi ini TIDAK membunuh teori SMC secara umum.**
   Yang terbukti salah: (a) sweep tanpa konfirmasi, (b) reaction-rate sebagai bukti
   profit, (c) volume-filter wajib. Yang selamat: (a) sweep + 1-bar confirmation gate,
   (b) geometri FVG. **Eksekusi nyata (limit order di zona diskon, SL/TP, biaya) belum
   dianalisis oleh modul ini** — itu domain `smc_limit_backtester` (prioritas berikutnya).

## 5. Keputusan yang diambil dari log ini

| Keputusan | Dari bukti |
|---|---|
| v1.6.1+: sweep hanya dihitung saat `CONFIRMED` | 48.2% -> 85.3% |
| v1.6.1+: OB volume sebagai preferensi, bukan gate | +5.4pp = no material edge |
| Timpa rekomendasi "reaction 90%" di UI dengan disclaimer | bias lookahead + selection |
| Bangun `smc_limit_backtester` (entry limit di zona, RR 1:2/1:3, IS 2022-23 / OOS 2024-26) | kebutuhan eksekusi nyata (Q3) |
| Daily vs limit-order: **no-go** (IS PF 0.68 / OOS PF 1.21, mayoritas timeout) | RR 2 tidak tercapai di daily; buka pipeline intraday M30/M5 |

## 6. Lanjutan: Limit-Order Backtester (IS vs OOS, data harian)

Setelah log ini ditulis, `ml_backend/services/smc_limit_backtester.py` dibangun untuk
menguji *eksekusi* yang tidak diuji di section 3: limit order yang diistirahatkan di 50%
zona FVG (equilibrium), SL di swing extreme terakhir, TP = 2R, di jalankan pada data
harian `GC=F` (1510 bar, 2020-09-25 -> 2026-09-25).

| Sesi | Sinyal | Filled | Fill-rate | Win-rate | PF | AvgR | Exit dominan |
|---|---|---|---|---|---|---|---|
| IS (2022-2023) | 69 | 47 | 68.1% | 44.7% | **0.681** | -0.10 | timeout (34) |
| OOS (2024-2026) | 55 | 37 | 67.3% | 59.5% | **1.207** | +0.05 | timeout (32) |

**The "Why" kedua**: RR 2.0 hampir tidak pernah tercapai di timeframe harian dalam 10
bar (target hanya 2x dari 84 filled). Mayoritas posisi keluar *timeout* — artinya harga
masuk zona lalu tidak menembus SL maupun TP; konklusi dirata-rata dari close bar
terakhir. IS negatif dan OOS hanya 1.2R marginal, dengan n kecil (per sesi < 70).
Putusan: **belum ada bukti alpha pada data harian**. Data yang tepat untuk pengujian
ini adalah **intraday (M30/M5)** — di situlah retrace ke zona dan target 2R terjadi
dalam hitungan jam, bukan minggu. Ini menutup Q3 dengan satu keputusan no-go yang jujur
untuk daily, dan membuka prioritas berikutnya: pipeline data intraday.

## 7. Reproduksi

```bash
cd ml_backend
python - <<'PY'
import yfinance as yf, pandas as pd
from services.smc_backtester import backtest_summary
df = yf.download("GC=F", period="5y", interval="1d", progress=False, auto_adjust=False)
if isinstance(df.columns, pd.MultiIndex):
    df.columns = df.columns.get_level_values(0)
print(backtest_summary(df.dropna()))
PY
```

Log di-generate: 2026-09-25 dengan probe ulang nyata (lihat angka di section 3).