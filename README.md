# Cangcilung Trading AI

Aplikasi Android/iOS untuk sinyal trading **XAUUSD, NASDAQ, AUDUSD** berbasis **AI/ML** — dibangun 100% di cloud.

```
Flutter App (HP) ⇄ FastAPI API (cloud) ⇄ Yahoo Finance
                      ├─ AI Prediksi Harga (Neural Network)
                      ├─ Technical Indicators (RSI, MACD, EMA, Bollinger)
                      ├─ Sentiment Analysis berita
                      └─ Sinyal BUY / SELL / HOLD
```

## Struktur Proyek

```
├── flutter_app/          # Frontend Flutter (Android + iOS)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── models/models.dart
│   │   ├── services/api_service.dart
│   │   ├── screens/home_screen.dart
│   │   └── widgets/candle_chart.dart
├── ml_backend/           # AI/ML Backend (Python FastAPI)
│   ├── main.py
│   ├── services/
│   │   ├── data_service.py   # Yahoo Finance + cache + fallback
│   │   ├── indicators.py     # RSI, MACD, EMA, Bollinger
│   │   ├── predictor.py      # model neural network (3 ensemble)
│   │   ├── sentiment.py      # sentiment berita berbobot + negasi
│   │   ├── signal.py         # generator sinyal BUY/SELL/HOLD (bobot dapat di-tune)
│   │   ├── backtest.py       # engine walk-forward backtest
│   │   └── tuner.py          # auto-tune bobot sinyal per simbol (grid search)
│   └── Dockerfile
├── .github/workflows/build-apk.yml   # Build APK otomatis di cloud
└── vercel.json                       # Konfigurasi deploy backend ke Vercel
```

## Cara Menggunakan (Cloud, tanpa install apapun)

### 1. Push kode ke GitHub
```bash
git add .
git commit -m "Initial: trading AI app"
git branch -M main
git remote add origin https://github.com/USERNAME/cangcilung-trading.git
git push -u origin main
```

### 2. Deploy backend (AI API) ke Vercel
1. Install Vercel CLI: `npm i -g vercel`, lalu login: `vercel login`
2. Dari folder `ml_backend`, jalankan: `vercel deploy --prod --yes`
3. Dapatkan URL produksi: `https://cangcilung-trading-api.vercel.app`
4. Vercel otomatis mendeteksi FastAPI di `main.py` (tanpa Docker/mangum)
5. Cek dengan membuka `https://cangcilung-trading-api.vercel.app/health` → harus `{"status": "ok"}`
6. (Opsional) Set **FINNHUB_API_KEY** gratis dari https://finnhub.io di **Vercel → Settings → Environment Variables** untuk sentiment berita aktual

### 3. Build APK di cloud (GitHub Actions)
Setelah push, buka tab **Actions** di GitHub:
- Workflow **"Build Android APK"** jalan otomatis setelah push ke `main`
- Atau jalankan manual: **Actions → Build Android APK → Run workflow**
- Setelah selesai (sekitar 5-10 menit), unduh APK dari **artifacts**:
  `cangcilung-trading-apk` → `app-release.apk`

### 4. Pasang APK di HP Android
- Salin `app-release.apk` ke HP, buka file → izinkan "Install unknown apps"
- **Catatan:** APK ini unsigned. Untuk publish di **Google Play**, kubutuhkan keystore signing & akun Play Console ($25).

### 5. Base URL API di aplikasi
Aplikasi sudah memakai `https://cangcilung-trading-api.vercel.app` sebagai default.
Jika URL Vercel kamu beda, ubah di `flutter_app/lib/services/api_service.dart` baris `defaultBaseUrl`, atau lewati saat build:
```
flutter build apk --release --dart-define=API_URL=https://URL-ANDA.vercel.app
```

## Endpoint API

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /health` | Health check |
| `GET /signal/XAUUSD` | Data lengkap (prediksi, indikator, sentiment, sinyal, chart) |
| `GET /signal/NASDAQ` | Sama, untuk NASDAQ |
| `GET /signal/AUDUSD` | Sama, untuk AUD/USD |
| `GET /warm` | Pramuat & cache semua simbol sekaligus (dijadwal otomatis via cron harian) |
| `GET /backtest/{symbol}` | Hasil backtest default vs bobot ter-tune (opsional `?days=30/60/90` untuk range bebas) |
| `GET /stats/{symbol}` | Akurasi rolling sinyal 7/14/30 hari + tren kualitas + akurasi nyata dari riwayat log |
| `GET /model` | Status model: bobot ter-tune per simbol + metrik backtest + akurasi rolling + validasi MLP walk-forward + hiperparameter grid + akurasi nyata |
| `GET /history/{symbol}` | Riwayat sinyal tercatat + hasil vs close hari berikutnya (untuk scoreboard) |
| `GET /docs` | Dokumentasi interaktif (Swagger UI) |

## AI / Training

- **Prediksi harga**: 3× MLP ensemble (lookback 12/24/36) + validasi walk-forward di `/model` (hit rate MLP nyata vs proxy momentum) + **grid hiperparameter (hidden/lr)** untuk konfigurasi terbaik.
- **Multi-timeframe**: konfirmasi tren 1h & 4h (EMA + slope) sebagai lapisan tetap kecil pada skor sinyal, ditampilkan sebagai `timeframe` di payload.
- **Auto-tune bobot sinyal**: grid search walk-forward per simbol (oscillator/trend/prediksi/sentimen) dengan pemisahan out-of-sample 70/30 anti-overfit — hasil terbaik otomatis dipakai untuk sinyal live dan di-cache 6 jam.
- **Feature engineering**: indikator klasik (RSI, MACD, EMA, Bollinger) + **volume konfirmasi tren** (z-score robust) + **posisi support/resistance** dimasukkan ke sinyal, backtest, dan tuning.
- **Backtest**: engine walk-forward menghitung win rate, profit factor, total return, dan max drawdown dari bobot default vs bobot ter-tune; mendukung `?days=` interaktif dari aplikasi.
- **Sentiment**: leksikon berbobot (kata kuat 2×) + penanganan negasi + tingkat keyakinan, dari berita gratis.
- **Pelacak akurasi sinyal**: `/stats/{symbol}` menghitung win rate rolling 7/14/30 hari dengan bobot ter-tune (tanpa penyimpanan — direkonstruksi deterministik dari data historis) + tren (membaik/memburuk).
- **Akurasi nyata (B1/B6)**: GitHub Actions mencatat sinyal harian ke `signals_log.json` (artefak repo), backend membacanya dan mengevaluasi sinyal TERHADAP CLOSE AKTUAL hari berikutnya di `/stats` & `/model`.
- **Riwayat sinyal / scoreboard**: `/history/{symbol}` + kartu "Riwayat Sinyal" di tab Model menampilkan setiap sinyal tercatat, harga saat log, hasil, dan status WIN/LOSS/pending.
- **Retraining terjadwal**: cron harian Vercel (21:00 UTC) memanggil `/warm` + fallback GitHub Actions (22:00 UTC).
- **Aplikasi**: Tab **Model** menampilkan akurasi rolling + akurasi nyata, profit factor, bobot, validasi MLP, dan **scoreboard riwayat sinyal** per simbol; **backtest interaktif** (pilih simbol + rentang); **notifikasi sinyal** dan **alert harga** lokal (cek berkala saat aplikasi terbuka, tanpa Firebase).

## iOS

Kode sudah mendukung iOS, tapi build & publish ke App Store **wajib punya Mac + akun Apple Developer ($99/tahun)** — ini batasan dari Apple, berlaku untuk semua framework.

## Disclaimer

Aplikasi ini bersifat **edukatif** dan menganalisis data historis serta berita. Hasil prediksi/sinyal **bukan jaminan profit** dan BUKAN saran finansial. Trading berisiko tinggi — gunakan dengan bijak.

## Pengembangan Lokal Backend (opsional)

```bash
cd ml_backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m uvicorn main:app --reload
```