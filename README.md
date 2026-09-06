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
│   │   ├── sentiment.py      # sentiment berita (Finnhub opsional)
│   │   └── signal.py         # generator sinyal BUY/SELL/HOLD
│   └── Dockerfile
├── .github/workflows/build-apk.yml   # Build APK otomatis di cloud
└── render.yaml                        # Deploy backend ke Render
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

### 2. Deploy backend (AI API) ke Render
1. Buat akun gratis di https://render.com
2. Klik **New → Blueprint**, connect repository GitHub kamu
3. Render akan otomatis membaca `render.yaml` dan deploy backend
4. Dapatkan URL backend, contoh: `https://cangcilung-trading-api.onrender.com`
5. Cek dengan membuka `https://URL/health` → harus `{"status": "ok"}`
6. (Opsional) Isi **FINNHUB_API_KEY** gratis dari https://finnhub.io untuk sentiment berita aktual

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
Aplikasi sudah memakai `https://cangcilung-trading-api.onrender.com` sebagai default.
Jika URL Render kamu beda, ubah di `flutter_app/lib/services/api_service.dart` baris `defaultBaseUrl`, atau lewati saat build:
```
flutter build apk --release --dart-define=API_URL=https://URL-ANDA.onrender.com
```

## Endpoint API

| Endpoint | Deskripsi |
|----------|-----------|
| `GET /health` | Health check |
| `GET /signal/XAUUSD` | Data lengkap (prediksi, indikator, sentiment, sinyal, chart) |
| `GET /signal/NASDAQ` | Sama, untuk NASDAQ |
| `GET /signal/AUDUSD` | Sama, untuk AUD/USD |
| `GET /docs` | Dokumentasi interaktif (Swagger UI) |

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