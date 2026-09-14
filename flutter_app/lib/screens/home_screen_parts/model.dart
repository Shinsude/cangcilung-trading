part of 'home_screen.dart';

class _ModelPage extends StatefulWidget {
  const _ModelPage({required this.model, required this.loading, required this.error, required this.onRetry, required this.notifyOn, required this.onToggleNotify, required this.api});

  final ModelInfo? model;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool notifyOn;
  final ValueChanged<bool> onToggleNotify;
  final ApiService api;

  @override
  State<_ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<_ModelPage> {
  final List<String> _btSymbols = ['XAUUSD', 'NASDAQ', 'AUDUSD'];
  String _btSymbol = 'XAUUSD';
  int? _btDays; // null = semua data
  bool _btLoading = false;
  String? _btError;
  BacktestResponse? _btResult;
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadHistory());
  }

  Future<void> _runBacktest() async {
    setState(() {
      _btLoading = true;
      _btError = null;
    });
    try {
      final result = await widget.api.fetchBacktest(_btSymbol, days: _btDays);
      if (!mounted) return;
      setState(() => _btResult = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _btError = 'Gagal menjalankan backtest: $e');
    } finally {
      if (mounted) setState(() => _btLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final data = await widget.api.fetchHistory(_btSymbol, limit: 30);
      if (!mounted) return;
      setState(() => _history = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.model == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.blue)),
            SizedBox(height: 14),
            Text('Melatih & memuat model\u2026', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }
    final m = widget.model;
    if (m == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat model', style: TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _ActionPill(label: 'Coba lagi', icon: Icons.refresh, onTap: widget.onRetry),
          ],
        ),
      );
    }

    final entries = m.symbols.entries.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('MODEL AI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(m.strategy, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4)),
        const SizedBox(height: 8),
        _NotifSetting(on: widget.notifyOn, onToggle: widget.onToggleNotify),
        const SizedBox(height: 14),
        _BacktestExplorer(
          symbols: _btSymbols,
          symbol: _btSymbol,
          days: _btDays,
          loading: _btLoading,
          result: _btResult,
          error: _btError,
          onSymbol: (s) {
            setState(() => _btSymbol = s);
            unawaited(_loadHistory());
          },
          onDays: (d) => setState(() => _btDays = d),
          onRun: () {
            unawaited(_runBacktest());
            unawaited(_loadHistory());
          },
        ),
        if (_history.isNotEmpty || _historyLoading) ...[
          const SizedBox(height: 14),
          _SignalHistoryCard(loading: _historyLoading, entries: _history),
        ],
        const SizedBox(height: 14),
        for (final e in entries) ...[
          _ModelCard(symbol: e.key, stats: e.value),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BacktestExplorer extends StatelessWidget {
  const _BacktestExplorer({required this.symbols, required this.symbol, required this.days, required this.loading, required this.result, required this.error, required this.onSymbol, required this.onDays, required this.onRun});

  final List<String> symbols;
  final String symbol;
  final int? days;
  final bool loading;
  final BacktestResponse? result;
  final String? error;
  final ValueChanged<String> onSymbol;
  final ValueChanged<int?> onDays;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final ranges = <int?>[null, 30, 60, 90];
    final labels = <int?, String>{null: 'SEMUA', 30: '30h', 60: '60h', 90: '90h'};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UJI BACKTEST', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 12),
          const Text('SINYAL', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final s in symbols) ...[
                _ChoiceChip(label: s, selected: symbol == s, onTap: () => onSymbol(s)),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Text('RENTANG', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final r in ranges) ...[
                _ChoiceChip(label: labels[r]!, selected: days == r, onTap: () => onDays(r)),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionPill(label: loading ? 'Menjalankan\u2026' : 'Jalankan Backtest', icon: loading ? null : Icons.play_arrow, onTap: loading ? null : onRun),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 11)),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: _Metric(label: 'Versi', value: 'AUTO-TUNE', color: AppColors.blue)),
                SizedBox(width: 8),
                Expanded(child: _Metric(label: 'Versi', value: 'DASAR', color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            _MetricRow(tuned: result!.tuned, baseline: result!.baseline),
            if (result!.tuned.equityCurve.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('KURVA EQUITY (AUTO-TUNE)', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              _EquityCurveChart(curve: result!.tuned.equityCurve),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.tuned, required this.baseline});
  final BacktestSummary tuned;
  final BacktestSummary baseline;

  @override
  Widget build(BuildContext context) {
    Color colorOf(double v, {bool invert = false}) {
      if (invert) v = -v;
      return v > 0 ? AppColors.green : (v < 0 ? AppColors.red : AppColors.textSecondary);
    }

    Widget rows(String label, String Function(BacktestSummary) pick, Color Function(BacktestSummary) col) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11))),
            Expanded(child: Text(pick(tuned), textAlign: TextAlign.right, style: TextStyle(color: col(tuned), fontSize: 12, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Expanded(child: Text(pick(baseline), textAlign: TextAlign.right, style: TextStyle(color: col(baseline), fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      );
    }

    return Column(
      children: [
        rows('Win Rate', (s) => '${(s.winRate * 100).toStringAsFixed(1)}%', (s) => colorOf(s.winRate - 0.5)),
        rows('Profit Factor', (s) => s.profitFactor.toStringAsFixed(2), (s) => s.profitFactor >= 1 ? AppColors.green : AppColors.red),
        rows('Total Return', (s) => '${(s.totalReturn * 100).toStringAsFixed(1)}%', (s) => colorOf(s.totalReturn)),
        rows('Max Drawdown', (s) => '${(s.maxDrawdown * 100).toStringAsFixed(1)}%', (s) => AppColors.red),
        rows('Trades', (s) => '${s.trades}', (s) => AppColors.blue),
      ],
    );
  }
}

class _EquityCurveChart extends StatelessWidget {
  const _EquityCurveChart({required this.curve});
  final List<EquityPoint> curve;

  @override
  Widget build(BuildContext context) {
    if (curve.isEmpty) return const SizedBox.shrink();
    final values = curve.map((p) => p.equity).toList();
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs();
    if (span < 1e-9) {
      minV -= 0.01;
      maxV += 0.01;
    }
    final finalV = values.last;

    return Container(
      height: 110,
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final n = values.length;
          final path = Path();
          for (var i = 0; i < n; i++) {
            final dx = n == 1 ? w / 2 : i / (n - 1) * w;
            final dy = h - (values[i] - minV) / (maxV - minV) * h;
            if (i == 0) {
              path.moveTo(dx, dy);
            } else {
              path.lineTo(dx, dy);
            }
          }
          final fill = Path.from(path)
            ..lineTo(n == 1 ? w / 2 : w, h)
            ..lineTo(0, h)
            ..close();
          final up = finalV >= 1.0;
          final col = up ? AppColors.green : AppColors.red;
          return CustomPaint(
            painter: _EquityPainter(path: path, fill: fill, color: col),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _EquityPainter extends CustomPainter {
  const _EquityPainter({required this.path, required this.fill, required this.color});
  final Path path;
  final Path fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _EquityPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.fill != fill || oldDelegate.color != color;
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.blue : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: selected ? 0.6 : 0.15)),
        ),
        child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _NotifSetting extends StatelessWidget {
  const _NotifSetting({required this.on, required this.onToggle});
  final bool on;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = on ? AppColors.green : AppColors.textSecondary;
    return GestureDetector(
      onTap: () => onToggle(!on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 20, color: c),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifikasi Sinyal', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Cek berkala saat aplikasi terbuka: muncul saat sinyal BUY/SELL baru. Push sejati butuh Firebase.', style: TextStyle(color: AppColors.textTertiary, fontSize: 9.5, height: 1.35)),
                ],
              ),
            ),
            Switch(value: on, onChanged: onToggle, activeTrackColor: AppColors.greenSoft, activeThumbColor: AppColors.green),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.symbol, required this.stats});
  final String symbol;
  final ModelStats stats;

  @override
  Widget build(BuildContext context) {
    final wr30 = stats.accuracy['30d']?.winRate ?? stats.backtest.winRate;
    final quality = wr30 > 0.55 ? AppColors.green : (wr30 > 0.45 ? AppColors.amber : AppColors.red);
    final pf = stats.backtest.profitFactor > 0 ? stats.backtest.profitFactor : 0.0;

    Color numColor(double v, {bool invert = false}) {
      if (invert) v = -v;
      return v > 0 ? AppColors.green : (v < 0 ? AppColors.red : AppColors.textSecondary);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: quality.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: quality.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(wr30 > 0.55 ? 'AKURAT' : (wr30 > 0.45 ? 'RATA-RATA' : 'LEMAH'), style: TextStyle(color: quality, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('AKURASI ROLLING (SINYAL BARU-BARU INI)', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final w in ['7d', '14d', '30d']) ...[
                Expanded(
                  child: _AccChip(
                    label: '$w:',
                    value: '${((stats.accuracy[w]?.winRate ?? 0) * 100).toStringAsFixed(0)}%',
                    color: (stats.accuracy[w]?.winRate ?? 0) > 0.55 ? AppColors.green : (stats.accuracy[w]?.winRate ?? 0) > 0.45 ? AppColors.amber : AppColors.red,
                  ),
                ),
                if (w != '30d') const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Text('BACKTEST WALK-FORWARD', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Profit Factor', value: pf.toStringAsFixed(2), color: pf >= 1 ? AppColors.green : AppColors.red)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Total Return', value: '${(stats.backtest.totalReturn * 100).toStringAsFixed(1)}%', color: numColor(stats.backtest.totalReturn))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Max Drawdown', value: '${(stats.backtest.maxDrawdown * 100).toStringAsFixed(1)}%', color: AppColors.red)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Trades', value: '${stats.backtest.trades}', color: AppColors.blue)),
            ],
          ),
          if (stats.realSamples > 0) ...[
            const SizedBox(height: 12),
            const Text('AKURASI NYATA (RIWAYAT SINYAL TERLOG)', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _AccChip(
                    label: 'Win rate:',
                    value: '${((stats.realWinRate ?? 0) * 100).toStringAsFixed(0)}%',
                    color: (stats.realWinRate ?? 0) > 0.55 ? AppColors.green : (stats.realWinRate ?? 0) > 0.45 ? AppColors.amber : AppColors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Metric(label: 'Sampel', value: '${stats.realSamples}', color: AppColors.blue)),
              ],
            ),
          ],
          if (stats.weights.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('BOBOT TER-TUNE', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats.weights.entries.map((e) => _WeightChip(label: e.key, weight: e.value)).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Text('Dilatih: ${stats.trainedAt.replaceFirst('T', ' ').replaceFirst('Z', '')}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _AccChip extends StatelessWidget {
  const _AccChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
          TextSpan(text: value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: AppColors.blue),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
