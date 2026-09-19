# Changelog

Semua perubahan dicatat di sini. Versi mengikuti [Semantic Versioning](https://semver.org/).

## [1.3.3] - 2026-09-19

### Diperbaiki
- **Kontras teks naik**: `textSecondary` → #94A3B8 (±7,5:1) dan `textTertiary` → #7B8AA5 (±5,5:1) terhadap latar #0A0E17 — kini lolos WCAG AA untuk teks normal.
- **Scaling teks sistem dihormati**: teks app mengikuti `textScaler` perangkat hingga 1,4× (ampan dari overflow tata letak padat).
- **Touch target diperbesar**: tombol notifikasi & mode ringkas di header (9→12 px), tombol salin sinyal (15→16 px + area tap lebih luas).

### Diubah
- **Kesehatan sistem & pipeline model pindah ke tab Model** (bukan lagi memenuhi tab Sinyal).
- **Tab Sinyal tidak lagi menduplikasi indikator**: strip indikator kilat (RSI/MACD/EMA) dihapus dari tab Sinyal — tab Indikator adalah rumah data tersebut.

### Ditambahkan
- **Layout web responsif**: semua tab kini dibatasi `max-width 720px` dan di-tengah — tidak melebar penuh di layar desktop.

## [1.3.2] - 2026-09-18

### Diubah
- **Hirarki tab Sinyal dibalik ke "keputusan dulu"**: urutan kartu kini Harga → Sinyal → Rencana Eksekusi → Posisi → Alert → Analisis Pasar → Rekap Harian → sisanya. Jalur menuju keputusan (entry/SL/TP) jadi pendek, tanpa scroll jauh.
- **Kartu konteks dipindah ke section "DETAIL & KONTEKS"** yang bisa dilipat (buka/tutup): timer candle M15, alur sesi, riwayat akurasi, strip indikator, skor lanjutan, pipeline, kesehatan sistem, dan panel edukasi — tidak lagi memenuhi layar sejak awal.
- **Mode Ringkas diperbaiki**: kini menyembunyikan hanya kartu konteks; Rencana Eksekusi & Posisi tetap tampil (sebelumnya ikut disembunyikan — sasaran yang salah).

## [1.3.1] - 2026-09-18

### Ditambahkan
- **Performa historis rezim saat ini** di kartu Analisis Mendalam: WR, jumlah trade, return, drawdown dari sinyal di rezim yang sama dengan kondisi pasar sekarang.
- **Mode riset mengikuti pilihan RENTANG** di tab Model; hasil `/research` kini bisa dipersempit ke jumlah bar tertentu (`days`).
- **Sorotan rezim aktif** di tabel per-rezim: baris kondisi pasar saat ini ditandai "SAAT INI".

## [1.3.0] - 2026-09-18

### Ditambahkan
- **Analisis struktur pasar** (`/signal` → field `market`): klasifikasi regime (TRENDING_UP/DOWN, TEKANAN, PELEMAHAN, CHOPPY, berbasis efisiensi Kaufman), volatilitas (state HIGH/NORMAL/LOW via rasio ATR), momentum (accelerasi/perlambatan/pembalikan), deteksi divergensi RSI & MACD, konfirmasi teknis (jumlah indikator searah sinyal), level pivot/support/resistance + jarak, serta rencana SL/TP berbasis ATR (RR 1:1 dan 1:1,67).
- **Kartu "Analisis Mendalam & Baca Pasar"** di tab Sinyal: ringkasan regime, peringatan divergensi, bar konfirmasi teknis, level harga, rencana SL/TP, dan penjelasan berbahasa Indonesia.
- **Endpoint riset `/research/{symbol}`**: backtest ketat (hanya sinyal baru menyilang ambang + biaya posisi 0,05%), breakdown win-rate/return per rezim pasar, dan uji sensitivitas ambang sinyal.
- **Kartu "Riset Backtest Ketat"** di tab Model dengan perbandingan realistis vs ketat.
- **Panel Edukasi Baca Pasar** di tab Sinyal (bisa dibuka/ditutup) — definisi singkat indikator, regime, divergensi, dan cara membaca sinyal.
- Versi app naik ke 1.3.0 (build 12).

### Diperbaiki
- Perhitungan action/confidence sinyal tidak diubah — modul analisis baru bersifat informatif agar backtest & akurasi nyata tetap stabil.

### Performa
- **Web 70% lebih ringan**: hosting pindah ke Vercel (brotli, `main.dart.js` 2,57 MB → 0,77 MB), cache CDN diatur (`no-cache` untuk runtime files, `immutable` untuk aset), service worker cache `stale-while-revalidate`.
- **Startup lebih cepat**: `PushService.init` non-blocking, `/digest` dan `/model` di-defer sampai tab dibuka, warm antar-simbol berurutan tanpa memblokir UI.
- **Backend lebih cepat**: timeout Yahoo Finance 12 s/percobaan, cache data 15 menit & respons 10 menit, fetch interval diparalelkan; payload `/signal` dipangkas (buang `candles` dead, 8,7 KB → 3 KB).
- **Bundle plugin hemat**: push/notifikasi di-*conditional import* — kode `workmanager` & `flutter_local_notifications` tidak lagi ikut ter-bundle ke web.
- **Keep-warm rutin**: cron GitHub Actions tiap 10 menit memanggil `/warm` (menggantikan `crons` Vercel yang hanya jalan di plan berbayar). Cold start `/signal` ±10 s, hangat ±0,5 s.

### Keandalan & akurasi
- **Sinyal sintetis tidak lagi diklaim real**: sinyal yang `data_source != live` tidak dicatat ke `signals_log.json`; entri sintetis historis ditandai dan **dikecualikan** dari `real_accuracy` (`/stats`).
- CI deploy otomatis (`deploy-web`, `deploy-api`) tersedia — aktif saat `VERCEL_TOKEN`/`VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` di-set.

### Diperbaiki
- Refactor: `home_screen.dart` (3.886 baris) dipecah menjadi library + 8 file `part` — tidak mengubah perilaku.
- Caching header Vercel tidak lagi memakai aturan `(.*)`/`max-age=600` yang bisa menyebabkan campuran versi file setelah deploy.

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