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

### 6b. Sensitivity + walk-forward membatalkan "no-go daily"

Kesimpulan 6a (**NO-GO DAILY**) ditulis dengan `retest_lookahead=10`. Sensitivity
check (grid lookahead 10/20/40 x RR 1.5/2.0/2.5, sejalan IS->OOS) membuktikan
sebaliknya: verdict itu adalah **artefak parameter**, bukan bukti.

| Lookahead | RR | IS PF | OOS PF | Pola |
|---|---|---|---|---|
| 10 | 2.0 | 0.68 | 1.21 | mayoritas timeout |
| **20** | **2.0** | **1.11** | **2.82** | timeout turun drastis, NAIK di kedua sesi |
| 40 | 2.0 | 1.45 | 2.52 | waktu tunggu terlalu lama |
| 40 | 2.5 | 1.57 | 2.52 | RR tinggi tidak menambah |

Pola IS->OOS naik bersamaan (180 derajat dari ciri curve-fit) = parameter genuine.
Di-lock `retest_lookahead=20, rr=2.0`.

**Verifikasi walk-forward per tahun (data harian, IS-tuning, param terkunci):**

| Tahun | Sinyal | Filled | Win-rate | PF | AvgR | Putusan |
|---|---|---|---|---|---|---|
| 2022 | 33 | 14 | 79% | **3.63** | +0.56 | kuat |
| 2023 | 36 | 36 | 50% | **0.63** | -0.16 | **tahun rugi** |
| 2024 | 34 | 22 | 64% | **4.37** | +0.38 | kuat |
| 2025 | 17 | 13 | 69% | **2.64** | +0.38 | positif |
| 2026 (parsial) | 4 | 4 | 100% | n/a | +1.28 | sampel terlalu kecil |

**The "Why" ketiga (walk-forward):** PF agregat OOS 2.82 di 6a menutup 2023 yang
full-losing (PF 0.63). Dua dari tiga tahun penuh positif kuat, satu tahun negatif.
Pola ini khas setup yang **bergantung rezim** (trending year menguntungkan, rentang/
news-heavy year menyakitkan), bukan edge statis. Putusan direvisi:

- **BUKAN "NO-GO"** — daily layak dihidupkan kembali dengan lookahead 20.
- **BUKAN "ALPHA TERBUKTI"** — 2023 jelas menutup kasus universal. Parameter sudah
  *terkunci* dan **tidak boleh di-tune terhadap tahun-tahun kalah** (di situ overfit
  dimulai).

### 6c. Verifikasi intraday (60m/30m) — bukti pertama di timeframe non-daily

Pipeline `services/intraday_research.py` mengambil data intraday dari yfinance
(batasan: 5m/15m/30m = ~60 hari, 60m/1h = ~730 hari) dan menjalankan mesin yang
sama `backtest_limit_entries` dengan parameter skala jam (zona 6 bar, SL 8 bar,
retest 24 bar, RR 2.0):

**Jalur A — `GC=F` 60m, 11451 bar (2024-09-26 -> 2026-09-25):**

| Sesi | Sinyal | Filled | Fill-rate | Win-rate | PF | Exit target/timeout/stop |
|---|---|---|---|---|---|---|
| IS (60%) | 982 | 384 | 39.1% | 48.4% | **1.436** | 92 / 128 / 164 |
| OOS (40%) | 477 | 200 | 41.9% | 50.5% | **1.540** | 57 / 55 / 88 |

PUTUSAN A: **hasil terbaik sejauh ini.** PF IS/OOS sejalan (1.44 -> 1.54, tidak
runtuh seperti 30m di bawah), win-rate OOS di atas 50%, dan exit *target* muncul
dalam jumlah besar (92/57 vs hanya 2 di daily) — konfirmasi bahwa RR 1:2 selesai
dalam hitungan jam di timeframe intraday, bukan minggu. Praktik langsung:
divergensi antara 0.39 fill-rate (retrace ke zona ~40% kasus) dan PF sehat itu
wajar; alpha tidak datang dari frekuensi, tapi dari kualitas menunggu.

**Stress biaya/slippage (sweep `cost_r`, biaya per trade dalam satuan R), 60m:**

| cost_r | IS PF | IS win% | IS avg-R | OOS PF | OOS win% | OOS avg-R |
|---|---|---|---|---|---|---|
| 0.00 | 1.436 | 48.4% | +0.202 | 1.540 | 50.5% | +0.244 |
| 0.05 | 1.310 | 47.9% | +0.152 | 1.407 | 49.5% | +0.194 |
| 0.10 | 1.198 | 47.7% | +0.102 | 1.286 | 48.5% | +0.144 |
| 0.20 | 1.003 | 44.5% | +0.002 | 1.079 | 46.5% | +0.044 |

Kalibrasi: untuk gold 1 jam, SL (swing extreme 8 bar) biasanya jauh di atas $10/oz
sedangkan spread+slippage membulat ~$1/oz (raw) -> `cost_r` realistis sekitar
**5-10% R**. Pada 0.10 R kedua sesi masih PF > 1.2; bahkan 0.20 R (pesimis dua
kali) menyisakan breakeven tipis. Artinya sinyal 60m **bukan artefak biaya** —
edge bertahan di komisi realistis. (Model ini belum memuat slippage dari *fill*
limit di bid-offer intra-1h serta perbedaan spread news; itu yang dicatat sebagai
keterbatasan forward-test, bukan alasan menyerah.)

**Jalur B — `GC=F` 30m, 2279 bar (60 hari terakhir):**

| Sesi | Sinyal | Filled | Fill-rate | Win-rate | PF |
|---|---|---|---|---|---|
| IS | 241 | 94 | 39.0% | 61.7% | **2.314** |
| OOS | 142 | 68 | 47.9% | 35.3% | **1.005** |

PUTUSAN B: **runtuh** — PF 2.31 hanya di IS, OOS datar (1.005) dengan win-rate
35%. Sampel 60 hari terlalu kecil dan satu rezim; statistik 68-94 trade tidak
cukup untuk mengambil kesimpulan apa pun selain *tidak boleh dipercaya*. Dipakai
sebagai peringatan metodologis, bukan angka.

**Kesimpulan 6c:** bukti terkuat repo ini ada di **60m (jalur A)**: IS/OOS serasi,
RR tercapai intraday. Sinyal *promising* naik dari "rezim-dependent" (daily) menjadi
"layak lanjut ke forward-test sungguhan pada 60m". Belum "alpha terbukti" — belum
ada biaya/slippage, n OOS = 200, dan jendela 2 tahun mencakup dua rezim. Tidak ada
penyesuaian parameter yang boleh dilakukan terhadap hasil ini (anti-curve-fit).
- Prioritas tetap: intraday M30/M5, di sana RR 1:2 selesai dalam jam bukan minggu,
  dan rezim bisa dipisah dari time-of-day.

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