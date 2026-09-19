part of 'package:cangcilung_trading/screens/home_screen.dart';

class _MiniScoreboard extends StatelessWidget {
  const _MiniScoreboard({required this.loading, required this.entries, this.hasError = false, this.onRetry});
  final bool loading;
  final List<Map<String, dynamic>> entries;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    int win = 0, loss = 0, pending = 0;
    for (final e in entries) {
      final o = (e['outcome'] as String?) ?? 'pending';
      if (o == 'win') {
        win++;
      } else if (o == 'loss') {
        loss++;
      } else if (o == 'pending') {
        pending++;
      }
    }
    final resolved = win + loss;
    final winRate = resolved > 0 ? win / resolved : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.scoreboard_rounded, size: 13, color: AppColors.purple),
              SizedBox(width: 6),
              Text('SCOREBOARD SINYAL', style: TextStyle(color: AppColors.purple, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)))
          else if (hasError)
            Row(
              children: [
                const Expanded(
                  child: Text('Gagal memuat riwayat.', style: TextStyle(color: AppColors.red, fontSize: 11)),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi', style: TextStyle(fontSize: 11))),
              ],
            )
          else if (entries.isEmpty)
            const Text('Belum ada data riwayat untuk simbol ini.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic))
          else ...[
            Row(
              children: [
                _sbStat('WIN', win, AppColors.green),
                const SizedBox(width: 8),
                _sbStat('LOSS', loss, AppColors.red),
                const SizedBox(width: 8),
                _sbStat('PENDING', pending, AppColors.amber),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${(winRate * 100).toStringAsFixed(0)}%', style: TextStyle(color: winRate >= 0.55 ? AppColors.green : (winRate >= 0.45 ? AppColors.amber : AppColors.red), fontSize: 18, fontWeight: FontWeight.w900)),
                    const Text('WIN RATE', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...entries.take(6).map((e) {
              final action = (e['action'] as String?) ?? 'HOLD';
              final outcome = (e['outcome'] as String?) ?? 'pending';
              final date = (e['date'] as String?) ?? '';
              final cThen = (e['close_then'] as num?)?.toDouble();
              final cNext = (e['close_next'] as num?)?.toDouble();
              final oc = outcome == 'win' ? AppColors.green : (outcome == 'loss' ? AppColors.red : AppColors.textSecondary);
              final ac = action == 'BUY' ? AppColors.green : (action == 'SELL' ? AppColors.red : AppColors.textSecondary);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(date.length > 5 ? date.substring(5) : date, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: ac.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(action, style: TextStyle(color: ac, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    if (cThen != null && cNext != null)
                      Text('${cThen.toStringAsFixed(cThen > 100 ? 0 : 5)} -> ${cNext.toStringAsFixed(cNext > 100 ? 0 : 5)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: oc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(outcome.toUpperCase(), style: TextStyle(color: oc, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _sbStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$value', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _SignalHistoryCard extends StatelessWidget {
  const _SignalHistoryCard({required this.loading, required this.entries, this.hasError = false, this.onRetry});
  final bool loading;
  final List<Map<String, dynamic>> entries;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RIWAYAT SINYAL (LOG AKURASI NYATA)', style: TextStyle(color: AppColors.purple, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('Hasil sinyal harian yang tercatat otomatis vs close hari berikutnya.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)))
          else if (hasError)
            Row(
              children: [
                const Expanded(
                  child: Text('Gagal memuat riwayat.', style: TextStyle(color: AppColors.red, fontSize: 12)),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi', style: TextStyle(fontSize: 12))),
              ],
            )
          else if (entries.isEmpty)
            const Text('Belum ada data riwayat. Log dimulai besok.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic))
          else
            ...entries.map((e) {
              final action = (e['action'] as String?) ?? 'HOLD';
              final outcome = (e['outcome'] as String?) ?? 'pending';
              final date = (e['date'] as String?) ?? '';
              final cThen = (e['close_then'] as num?)?.toDouble();
              final cNext = (e['close_next'] as num?)?.toDouble();
              final oc = outcome == 'win' ? AppColors.green : (outcome == 'loss' ? AppColors.red : AppColors.textSecondary);
              final ac = action == 'BUY' ? AppColors.green : (action == 'SELL' ? AppColors.red : AppColors.textSecondary);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(date.length > 5 ? date.substring(5) : date, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: ac.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(action, style: TextStyle(color: ac, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    if (cThen != null && cNext != null)
                      Expanded(
                        child: Text(
                          '${cThen.toStringAsFixed(cThen > 100 ? 0 : 5)} \u2192 ${cNext.toStringAsFixed(cNext > 100 ? 0 : 5)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: oc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(outcome.toUpperCase(), style: TextStyle(color: oc, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 16),
            const Text('Cara Pakai', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Panduan singkat membaca Cangcilung Trading AI', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            const _GuideSection(
              icon: Icons.traffic_rounded,
              title: '1. Membaca sinyal',
              body:
                  'BUY = peluang naik, SELL = peluang turun, HOLD = tunggu. Kekuatan STRONG lebih yakin daripada MODERATE. Persentase di kartu sinyal = tingkat keyakinan model, bukan jaminan. Selalu cek tab Indikator & Chart untuk konfirmasi.',
            ),
            const _GuideSection(
              icon: Icons.alt_route_rounded,
              title: '2. Plan Entry (SL/TP)',
              body:
                  'Saat sinyal BUY/SELL muncul, kartu Plan Entry memberi harga masuk (Entry), Stop Loss (SL) dan Take Profit (TP) berbasis ATR. Risk-reward 1.67 artinya potensi profit 1.67x risiko. Jangan risiko lebih dari 1-2% saldo per trade.',
            ),
            const _GuideSection(
              icon: Icons.notifications_active_rounded,
              title: '3. Notifikasi otomatis',
              body:
                  'Aktifkan ikon lonceng di kanan atas. App mengecek sinyal baru setiap 1 jam di latar belakang (Android) meski app tertutup dan setiap 5 menit saat app dibuka, lalu memunculkan notifikasi lokal. Tanpa Firebase: ini polling, bukan push instan \u2014 mungkin tertunda beberapa menit.',
            ),
            const _GuideSection(
              icon: Icons.flag_rounded,
              title: '4. Alert harga',
              body:
                  'Ketik harga target di bawah sinyal. App memeriksa harga tiap 5 menit saat aplikasi aktif dan menampilkan notifikasi saat level tersentuh. Penting: tanpa infrastruktur push, alert tidak dijamin real-time dan tidak berfungsi saat app benar-benar tertutup.',
            ),
            const _GuideSection(
              icon: Icons.candlestick_chart_rounded,
              title: '5. Simbol yang didukung',
              body: 'Simbol yang didukung saat ini: XAUUSD (Emas), NASDAQ, dan AUDUSD. Pilih dari bar di atas untuk berpindah.',
            ),
            const _GuideSection(
              icon: Icons.psychology_rounded,
              title: '6. Model & akurasi',
              body:
                  'Tab Model menampilkan backtest walk-forward (win-rate, drawdown) dan akurasi nyata dari sinyal historis. Model MLP dilatih ulang otomatis. Akurasi >55% dianggap baik, <45% lemah \u2014 perhatikan tren sebelum mengikuti sinyal.',
            ),
            const _GuideSection(
              icon: Icons.warning_amber_rounded,
              title: 'Disclaimer',
              body:
                  'Sinyal adalah hasil analisis statistik otomatis, bukan saran keuangan. Pasar bisa bergerak melawan prediksi. Trading berisiko tinggi \u2014 gunakan uang yang siap hilang dan kelola risiko dengan disiplin.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
