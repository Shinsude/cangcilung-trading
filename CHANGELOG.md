# Changelog

Semua perubahan dicatat di sini. Versi mengikuti [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-09-14

### Ditambahkan
- **Label sumber data**: payload `/signal` dan `/digest` kini memuat field `data_source` (`live` | `synthetic`). Saat Yahoo Finance gagal/kena rate-limit, app menampilkan banner peringatan "Data simulasi — jangan untuk trading nyata".
- **Backend test**: suite `pytest` deterministik (tanpa network) untuk indikator, prediksi, backtest, dan fallback data; dijalankan oleh job CI baru `backend-test` setiap push.
- Clamp prediksi return (±25%) di `predictor.py` agar tidak `inf` (overflow `np.exp`).

### Keamanan / sanity
- `/alerts` kini punya guard: dedup 1 alert per (device, simbol), cap maks 12 alert per device, validasi panjang `device_id`.

### Kejujuran dokumentasi
- Teks fitur diperjelas: notifikasi & alert harga adalah **polling lokal** (`WorkManager` 1 jam; cek 5 menit saat app aktif), **bukan push server real-time**. Tanpa Firebase/tanpa storage persisten bersama, alert server di Vercel `_best-effort` (in-memory per instance serverless).
- README/CHANGELOG dirombak memperbaiki klaim yang sebelumnya berlebihan.

### Diperbaiki
- Hapus menu & fitur Chart (tab ke-2, class `_ChartPage`, widget `CandleChart`) — 5 tab tersisa.

## [1.0.0] - 2026-09-11

Rilis perdana: sinyal AI multi-simbol, indikator, kalender, sentiment, model & akurasi, notifikasi lokal, alert harga, backtest, rekap harian, sistim health, scoreboard, rekomendasi sesi, dan equity curve.