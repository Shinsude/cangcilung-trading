# Changelog

Semua perubahan dicatat di sini. Versi mengikuti [Semantic Versioning](https://semver.org/).

## [Unreleased] - Scientific Record (research/)

### Ditambahkan
- **`services/intraday_research.py`**: pipeline probe intraday — fetch 5m/15m/30m (60 hari) dan 60m/1h (730 hari) untuk `GC=F`; memakai mesin `backtest_limit_entries` dengan parameter skala jam (zona 6 bar, SL 8 bar, retest 24 bar, RR 2.0).
- **Probe intraday 60m (11451 bar, 2024-09-26 -> 2026-09-25)**: IS PF 1.436 / OOS PF 1.54, win-rate OOS 50.5%, exit target 92/57 — hasil terbaik repo, RR 1:2 tercapai di timeframe intraday, tidak runtuh antar-sesi.
- Probe 30m (60 hari): IS PF 2.314 / OOS PF 1.005 — **runtuh**, sampel tak cukup, dicatat sebagai peringatan metodologis di falsification log (section 6c).
- 3 unit test intraday (fetch di-mock, tanpa network). Total 81 passed.

### Diperbaiki
- **`smc_limit_backtester.simulate_limit` tidak meneruskan `sl_bars`**: parameter SL window sekarang mengalir dari `backtest_limit_entries` melalui `_run_slice` ke `simulate_limit` — membuat parameter skala jam intraday benar-benar efektif (sebelumnya selalu SL default 20 bar).

### Terdokumentasi
- Falsification log section 6c: bukti pertama di timeframe non-daily; kesimpulan "promising" naik dari rezim-dependent (daily) ke "layak forward-test 60m", anti-curve-fit.
- **`research/01_baseline_falsification.md`**: buku catatan laboratorium (falsification log) — dokumentasi jujur hipotesis vs hasil untuk semua setup SMC yang diuji, termasuk "why" dan keputusan yang diambil.
- **`smc_limit_backtester.py`**: backtest eksekusi *pending limit* — ChoCh (swing-based) + premium/discount, limit istirahat di 50% zona FVG (equilibrium), SL di swing extreme, TP RR 1:2/1:3, split In-Sample/Out-of-Sample. Hasil harian IS 2022-23 (PF 0.68) vs OOS 2024-26 (PF 1.21) mayoritas exit timeout → keputusan no-go untuk daily, prioritas pipeline intraday.
- **DST-aware session detection**: `detect_session()` kini memakai `zoneinfo` (`Europe/Bucharest`, EET/EEST) sehingga sesi tidak bergeser 1 jam saat transisi DST Maret/Oktober; helper `convert_utc_to_broker_time()` dan `broker_utc_offset_hours()` + 7 unit test DST transition.
- 14 unit test baru (DST 7 + limit backtester 7). Total 77 passed.

### Diperbaiki
- **Split IS/OOS di `smc_limit_backtester` mengabaikan `is_start`/`is_end`**: kondisi split 60/40 hanya dibuat saat `oos_start=None`, sehingga panggilan per-tahun (is saja, tanpa oos) selalu memakai 60/40 penuh — semua tahun mengembalikan angka identik. Kini split 60/40 hanya aktif bila semua rentang kosong + 1 test anti-regresi.
- **Sensitivity + walk-forward merevisi verdict daily**: no-go di lookahead 10 ternyata artefak parameter (mayoritas exit timeout). Dengan `retest_lookahead=20` IS PF 1.11 vs OOS PF 2.82; walk-forward per tahun mengungkap 2023 full-losing (PF 0.63) — 2022/2024/2025 positif. Putusan: promising tapi bergantung rezim, parameter terkunci (lookahead=20, RR=2.0). Total 78 passed.

## [1.5.0] - 2026-09-21

### Diubah
- **Fokus satu aset: XAUUSD (Emas)**. Nasdaq dan AUDUSD dihapus dari seluruh aplikasi: bar pemilih simbol, backtest, notifikasi, automasi, sentimen, dan API backend (daftar simbol, digest, warm-up, alert). Backend kini hanya melayani `XAUUSD` (`GC=F`) dengan jalur lebih sederhana.

## [1.4.1] - 2026-09-21

### Diperbaiki
- **Basis Futur–Fisik Emas diperbaiki**: Yahoo sudah tidak menyediakan seri spot `XAUUSD=X` (404), sehingga basis sebelumnya kosong. Kini memakai **GLD** sebagai proxy fisik dan dihitung sebagai *premium/diskonto* futures (`GC=F`) relatif terhadap baseline rasionya sendiri 60 hari (bukan klaim kontango/backwardation absolut). Status `PREMIUM` / `DISKONTO` / `NETRAL` + rata-rata 20 hari. Label UI diubah menjadi "BASIS FUTUR–FISIK" dengan keterangan `(GLD)` agar tetap jujur terhadap sumber data.
- **Kestabilan data**: `yfinance` dinaikkan `0.2.54 → 1.6.0` (mengatasi rate-limit Yahoo yang membuat fetch tambahan GLD kosong di server), timeout unduh dinaikkan (12s → 20s), dan seri GLD di-cache lebih lama (1 jam).

## [1.4.0] - 2026-09-19

### Ditambahkan
- **Kartu Volume Profile di tab Sinyal** (DETAIL & KONTEKS): menampilkan POC, VAH, VAL, lebar Value Area, posisi harga (di atas / di dalam / di bawah area nilai), dan jarak ke POC — distribusi volume-at-price ~6 bulan terakhir sebagai proxy di mana likuiditas institusional tertanam.
- **Tile POC & VA WIDTH di grid Indikator Teknikal** saat data volume profile tersedia.
- **CVD Divergence (chip FLOW)**: membandingkan arah harga vs kumulatif delta volume (proxy) — bila harga bullish tapi aliran volume mengecewakan, muncul chip `FLOW BULLISH/BEARISH` merah dan masuk daftar kelemahan sinyal.
- **Basis Futur–Spot untuk Emas (XAUUSD)**: status kontango/backwardation antara `GC=F` dan `XAUUSD=X` beserta rata-rata 20 hari (konteks, bukan sinyal).

### Diperbaiki
- **Disclaimer kejujuran data**: "CVD & efisiensi = estimasi dari data harga harian (proxy), bukan order-flow riil" — ditampilkan permanen di ANALISIS LANJUTAN agar pengguna tahu batas data ritel.

## [1.3.6] - 2026-09-19

### Diubah
- **Navigasi dipangkas 5 → 3 tab: Sinyal / Berita / Model.**
  - Tab Sentimen + Kalender digabung jadi **Berita** (sentimen pasar di atas, kalender ekonomi di bawah, satu pull-to-refresh).
  - Tab Indikator digabung ke **Sinyal**: indikator teknikal kini bagian dari section "DETAIL & KONTEKS".
- **Mode ringkas dihapus**: selalu tampil lengkap, tidak perlu toggle "sembunyikan detail".
- **Kartu "Rencana → Posisi → Alert" dilebur jadi satu kartu Level** di tab Sinyal: alur keputusan (entry/SL/TP → PnL posisi → alert harga) dalam satu urutan tanpa kartu yang berhamburan.
- **Efek dekoratif dihilangkan**: tilt 3D & denyut pulsa pada kartu sinyal, gradient + box-shadow pada kartu harga/rekap/sentimen dibuang — kartu memakai permukaan datar dengan border netral agar hirarki datang dari konten, bukan efek.
- Kartu RISET BACKTEST KETAT & uji backtest di netralkan bordernya (tetap pakai warna aksen hanya pada judul/chip).

### Diperbaiki
- **Bobot model tetap tampil**: chips "BOBOT TER-TUNE" pada status model dipertahankan saat indikator tab digabung ke Sinyal.

## [1.3.5] - 2026-09-19

### Ditambahkan
- **Refresh otomatis mengikuti tutup candle M15**: sinyal di-refresh diam-diam beberapa detik setelah setiap candle 15 menit menutup — tab tidak lagi menampilkan data basi tanpa disadari sambil terbuka.
- **Tombol "Segarkan data" di header** (web/desktop kini punya cara refresh manual; tidak hanya gesture tarik yang butuh layar sentuh).

### Diperbaiki
- **Label usia data tampil akurat**: "Diperbarui …" di kartu harga kini bertambah sendiri setiap 30 detik, bukan membeku sampai tab diganti.
- **Pesan error ramah**: teks exception mentah diganti kalimat manusia ("Waktu koneksi habis…", "Koneksi gagal…") pada kegagalan muat data utama & model.
- **Aksesibilitas keyboard web**: tombol notifikasi & mode ringkas kini `InkWell` (fokus Tab + semantik tombol), konsisten dengan tombol help.
- **Terminologi tab konsisten**: tab pertama "Signal" → "Sinyal".

### Diubah
- **Jargon diberi penjelasan**: THETA, TS, SNR, DECOMP, BAR, SAFE di kartu System Health kini punya tooltip penjelasan saat ragu.

## [1.3.4] - 2026-09-19

### Diperbaiki
- **Ukuran font dasar naik global**: tidak ada lagi teks infonya yang lebih kecil dari 10 px; mayoritas teks info kini 11 px (sebelumnya banyak 8–9 px di label, chip, timestamp).
- **State tab dipertahankan** (IndexedStack lazy): Kalender tidak refetch tiap kali pindah tab, posisi scroll & buku status tiap tab tersimpan; tab lain tetap dibangun malas (lazy) pada kunjungan pertama agar startup tidak bertambah beban.
- **Membersihkan komponen desain mati**: `GlassCard` & `GlowCard` (tak terpakai) beserta warna `glass`/`glassBorder` dihapus dari tema.

### Housekeeping
- Workflow CI naik ke runtime Node.js 24: `checkout@v5`, `setup-node@v5`, `setup-python@v6`, `upload-artifact@v6`, `download-artifact@v7` — peringatan "Node 20 deprecated" hilang.

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