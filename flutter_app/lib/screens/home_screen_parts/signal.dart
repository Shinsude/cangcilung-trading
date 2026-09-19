part of 'package:cangcilung_trading/screens/home_screen.dart';

class _SignalPage extends StatelessWidget {
  const _SignalPage({required this.data, required this.onRefresh, required this.alertTarget, required this.onSetAlert, required this.onClearAlert, this.confHistory = const [], this.history = const [], this.historyLoading = false, this.historyError = false, this.onRetryHistory, this.digest, this.onSelectSymbol});

  final TradingData data;
  final Future<void> Function() onRefresh;
  final double? alertTarget;
  final VoidCallback onSetAlert;
  final VoidCallback onClearAlert;
  final List<double> confHistory;
  final List<Map<String, dynamic>> history;
  final bool historyLoading;
  final bool historyError;
  final VoidCallback? onRetryHistory;
  final MorningDigest? digest;
  final ValueChanged<String>? onSelectSymbol;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PriceHero(data: data),
          if (data.dataSource != 'live') ...[
            const SizedBox(height: 8),
            _DataSourceWarning(source: data.dataSource),
          ],
          const SizedBox(height: 14),
          _SignalHero(signal: data.signal, prediction: data.prediction, price: data.currentPrice, decimals: data.decimals, advanced: data.advanced, confHistory: confHistory),
          const SizedBox(height: 14),
          _LevelCard(risk: data.risk, position: data.position, decimals: data.decimals, alertTarget: alertTarget, price: data.currentPrice, onSetAlert: onSetAlert, onClearAlert: onClearAlert),
          if (data.market != null) ...[
            const SizedBox(height: 14),
            _MarketCard(market: data.market!),
          ],
          if (digest != null) ...[
            const SizedBox(height: 14),
            _DigestCard(digest: digest!, onSelect: onSelectSymbol),
          ],
          const SizedBox(height: 14),
          _DetailSection(
            children: [
              const _CandleTimer(),
              const _SessionTimeline(),
              _MiniScoreboard(loading: historyLoading, entries: history, hasError: historyError, onRetry: onRetryHistory),
              _IndicatorBlock(ind: data.indicators, vp: data.institutional?.vp, decimals: data.decimals),
              if (data.institutional != null) _VolumeProfileCard(inst: data.institutional!, decimals: data.decimals),
              _AdvancedScores(adv: data.advanced),
              const _EducationPanel(),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataSourceWarning extends StatelessWidget {
  const _DataSourceWarning({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final synthetic = source == 'synthetic';
    final msg = synthetic
        ? 'Data pasar tidak tersedia saat ini. Sinyal memakai data simulasi \u2014 jangan untuk trading nyata.'
        : 'Harga/timestamp data mencurigakan (stale). Verifikasi sebelum eksekusi.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatefulWidget {
  const _DetailSection({required this.children});

  final List<Widget> children;

  @override
  State<_DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<_DetailSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) items.add(const SizedBox(height: 14));
      items.add(widget.children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('DETAIL & KONTEKS',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                  child: Text('${widget.children.length} item',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: items)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DigestCard extends StatelessWidget {
  const _DigestCard({required this.digest, this.onSelect});

  final MorningDigest digest;
  final ValueChanged<String>? onSelect;

  Color _actionColor(String action) {
    switch (action) {
      case 'BUY':
        return AppColors.green;
      case 'SELL':
        return AppColors.red;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 15, color: AppColors.amber),
              const SizedBox(width: 8),
              const Text('REKAP HARIAN', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(width: 8),
              Text(digest.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in digest.symbols)
            GestureDetector(
              onTap: onSelect == null ? null : () => onSelect!(s.symbol),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      child: Text(s.symbol, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _actionColor(s.action).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('${s.action}${s.strength.isNotEmpty ? '\u00B7${s.strength}' : ''}', style: TextStyle(color: _actionColor(s.action), fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _predictionText(s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                    if (s.price != null)
                      Text(
                        _fmt(s.price!),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsFixed(4);
  }

  String _predictionText(DigestSymbol s) {
    final np = s.nextPrice;
    if (np == null || s.action == 'HOLD') return 'tunggu sinyal';
    final arrow = s.direction == 'UP' ? '\u25B2' : '\u25BC';
    return '$arrow $np ${s.horizon}';
  }
}

class _PriceHero extends StatelessWidget {
  const _PriceHero({required this.data});
  final TradingData data;

  @override
  Widget build(BuildContext context) {
    final up = data.changePct >= 0;
    final accent = up ? AppColors.green : AppColors.red;
    final priceStr = data.currentPrice.toStringAsFixed(data.decimals);
    final changeStr = '${up ? '+' : ''}${data.changePct.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                ),
                child: Text(data.category.toUpperCase(), style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text(data.symbol, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3)),
              const Spacer(),
              Text(data.name, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            key: ValueKey(priceStr),
            tween: Tween(begin: 1.04, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: v > 1.0 ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: Text(
              priceStr,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 15, color: accent),
                const SizedBox(width: 4),
                Text(changeStr, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
          if (data.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _UpdatedLabel(at: data.updatedAt!),
            ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}

class _UpdatedLabel extends StatefulWidget {
  const _UpdatedLabel({required this.at});
  final DateTime at;

  @override
  State<_UpdatedLabel> createState() => _UpdatedLabelState();
}

class _UpdatedLabelState extends State<_UpdatedLabel> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Diperbarui ${_relativeTime(widget.at)}',
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, letterSpacing: 0.3),
    );
  }
}

class _ConfidenceSparkline extends StatelessWidget {
  const _ConfidenceSparkline({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('KEYAKINAN TERAKHIR', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            Text(values.last.toStringAsFixed(3), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 18,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparkPainter(values: values, min: min, range: range, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.values, required this.min, required this.range, required this.color});
  final List<double> values;
  final double min;
  final double range;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final y = size.height - ((values[i] - min) / range) * size.height;
      final x = i * dx;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}

class _SignalHero extends StatelessWidget {
  const _SignalHero({required this.signal, required this.prediction, required this.price, required this.decimals, this.advanced, this.confHistory = const []});

  final Signal signal;
  final Prediction prediction;
  final double price;
  final int decimals;
  final Advanced? advanced;
  final List<double> confHistory;

  @override
  Widget build(BuildContext context) {
    final sigColor = signal.action.toSignalColor();
    final dirColor = prediction.direction.toSignalColor();
    final arrow = prediction.direction == 'UP' ? '\u25B2' : prediction.direction == 'DOWN' ? '\u25BC' : '\u25C6';
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;

    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SINYAL TRADING', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: sigColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(signal.strength.toUpperCase(), style: TextStyle(color: sigColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
                GestureDetector(
                  onTap: () => _copySignal(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.action,
                      style: TextStyle(
                        color: sigColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(_score2icon(signal.confidence), size: 15, color: sigColor),
                        const SizedBox(width: 4),
                        Text(
                          '${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(arrow, style: TextStyle(color: dirColor, fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(prediction.direction, style: TextStyle(color: dirColor, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction.nextPrice.toStringAsFixed(decimals),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% \u00B7 ${prediction.horizon}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: signal.confidence),
                duration: const Duration(milliseconds: 800),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceAlt,
                  color: sigColor,
                ),
              ),
            ),
            if (confHistory.length >= 2) ...[
              const SizedBox(height: 12),
              _ConfidenceSparkline(values: confHistory, color: sigColor),
            ],
            if (advanced != null) ...[
              const SizedBox(height: 12),
              _AdvancedBadges(adv: advanced!),
            ],
          ],
        ),
    );
  }

  IconData _score2icon(double c) => c >= 0.75 ? Icons.local_fire_department_rounded : Icons.bolt_rounded;

  void _copySignal(BuildContext context) {
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;
    final text = [
      'Cangcilung Trading AI',
      'Sinyal: ${signal.action} (${signal.strength}) \u00B7 ${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
      'Harga: ${price.toStringAsFixed(decimals)}',
      'Prediksi ${prediction.horizon}: ${prediction.direction == 'UP' ? 'naik' : prediction.direction == 'DOWN' ? 'turun' : 'netral'} \u2192 ${prediction.nextPrice.toStringAsFixed(decimals)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
      signal.summary,
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ringkasan sinyal disalin ke clipboard'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceAlt,
    ));
  }
}

class _AdvancedBadges extends StatelessWidget {
  const _AdvancedBadges({required this.adv});
  final Advanced adv;

  @override
  Widget build(BuildContext context) {
    final regimeColor = adv.regime.contains('BULL') ? Colors.green : adv.regime.contains('BEAR') ? Colors.red : adv.regime == 'RANGING' ? Colors.amber : Colors.grey;
    return Column(
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _mtfBadge('D1', adv.mtfD1Dir),
            _mtfBadge('H4', adv.mtfH4Dir),
            _mtfBadge('H1', adv.mtfH1Dir),
            _mtfBadge('M30', adv.mtfM30Dir),
            _mtfBadge('M15', adv.mtfM15Dir),
            _pill('ALIGN', '${(adv.mtfAlignment * 100).toInt()}%', adv.mtfAlignment > 0.3 ? Colors.green : adv.mtfAlignment < -0.3 ? Colors.red : Colors.grey),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill('REGIME', adv.regime, regimeColor),
            _pill('VOL', adv.volatilityRegime, adv.volatilityRegime == 'HIGH' ? Colors.orange : adv.volatilityRegime == 'LOW' ? Colors.cyan : Colors.grey),
            _sessionBadge(adv.session),
            _pill('GRADE', adv.grade, _gradeColor(adv.grade)),
            _pill('STAB', adv.stability, adv.stability == 'HIGH' ? Colors.green : adv.stability == 'MEDIUM' ? Colors.amber : Colors.red),
            if (adv.smcWarning) ...[
              _pill('SMC', 'WARN', Colors.orange),
            ],
          ],
        ),
        if (adv.weaknesses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: adv.weaknesses.take(3).map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(w, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _mtfBadge(String tf, String dir) {
    final c = dir == 'BULLISH' ? Colors.green : dir == 'BEARISH' ? Colors.red : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text('$tf $dir', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sessionBadge(String session) {
    final c = session.contains('LONDON') ? Colors.green : session.contains('ASIA') ? Colors.cyan : session.contains('NEW') ? Colors.amber : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(session, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _pill(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'ULTIMATE': return Colors.amber;
      case 'APLUS': return Colors.green;
      case 'A': return Colors.lightGreen;
      case 'BPLUS': return Colors.blue;
      case 'B': return Colors.cyan;
      default: return Colors.grey;
    }
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.risk, required this.position, required this.decimals, required this.alertTarget, required this.price, required this.onSetAlert, required this.onClearAlert});

  final Risk risk;
  final PositionPlan position;
  final int decimals;
  final double? alertTarget;
  final double price;
  final VoidCallback onSetAlert;
  final VoidCallback onClearAlert;

  @override
  Widget build(BuildContext context) {
    final showPlan = risk.available;
    final showPos = position.open;
    final planNote = risk.note ?? '';
    final showTop = showPlan || planNote.isNotEmpty || showPos;
    final planCol = risk.side == 'SELL' ? AppColors.red : AppColors.green;
    final posCol = position.side == 'SELL' ? AppColors.red : AppColors.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPlan) ...[
            Row(
              children: [
                Icon(risk.side == 'SELL' ? Icons.south_rounded : Icons.north_rounded, size: 15, color: planCol),
                const SizedBox(width: 6),
                const Text('RENCANA', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const Spacer(),
                Text('RR ${risk.riskReward.toStringAsFixed(2)}', style: TextStyle(color: planCol, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _PlanCell(label: 'Entry', value: fmt(risk.entry), color: AppColors.textPrimary)),
                Expanded(child: _PlanCell(label: 'Stop Loss', value: fmt(risk.stopLoss), color: AppColors.red)),
                Expanded(child: _PlanCell(label: 'Take Profit', value: fmt(risk.takeProfit), color: AppColors.green)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Rekomendasi: risk maksimal 1-2% saldo. SL/TP dihitung dari ATR (${risk.atr.toStringAsFixed(decimals >= 3 ? 5 : 2)}).',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ] else if (planNote.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(planNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              ],
            ),
          ],
          if (showPos) ...[
            if (showPlan || planNote.isNotEmpty) const Divider(color: AppColors.border, height: 22),
            Row(
              children: [
                Icon(position.side == 'SELL' ? Icons.south_rounded : Icons.north_rounded, size: 15, color: posCol),
                const SizedBox(width: 6),
                const Text('POSISI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const Spacer(),
                _chip(position.status == 'OPEN' ? 'OPEN' : position.status, _statusColor),
                const SizedBox(width: 6),
                Text(_fmtOpened, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(position.pnlPct >= 0 ? '+' : '', style: TextStyle(color: pnlCol, fontSize: 15, fontWeight: FontWeight.w800)),
                Text('${position.pnlPct.toStringAsFixed(2)}%', style: TextStyle(color: pnlCol, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${position.points >= 0 ? '+' : ''}${position.points.toStringAsFixed(decimals)}', style: TextStyle(color: pnlCol, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _PlanCell(label: 'Entry', value: fmt(position.entryPrice), color: AppColors.textPrimary)),
                Expanded(child: _PlanCell(label: 'Now', value: fmt(position.currentPrice), color: pnlCol)),
                Expanded(child: _PlanCell(label: 'SL', value: fmt(position.stopLoss), color: AppColors.red)),
                Expanded(child: _PlanCell(label: 'TP', value: fmt(position.takeProfit), color: AppColors.green)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (position.trailActive && position.trailLevel != null)
                  _chip('TRAIL ${fmt(position.trailLevel!)}', AppColors.amber)
                else if (position.stopLoss > 0)
                  _chip('SL ${fmt(position.stopLoss)}', AppColors.red),
                _chip('TP ${fmt(position.takeProfit)}', AppColors.green),
                if (position.trailActive)
                  _chip('LOCK +${position.profitLockedPct.toStringAsFixed(2)}%', AppColors.blue),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Simulasi dari sinyal terakhir \u2014 bukan akun MT5 live.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
          ],
          if (showTop) const Divider(color: AppColors.border, height: 22),
          Row(
            children: [
              Icon(alertTarget != null ? Icons.notifications_active_rounded : Icons.low_priority, size: 18, color: alertTarget != null ? AppColors.amber : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: alertTarget != null
                    ? Text('Target ${alertTarget!.toStringAsFixed(decimals)} \u2022 Harga kini ${price.toStringAsFixed(decimals)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))
                    : const Text('Setel alert harga \u2022 dicek tiap 5 menit saat app aktif', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
              InkWell(
                onTap: alertTarget != null ? onClearAlert : onSetAlert,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (alertTarget != null ? AppColors.red : AppColors.blue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(alertTarget != null ? 'HAPUS' : 'SETEL', style: TextStyle(color: alertTarget != null ? AppColors.red : AppColors.blue, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String fmt(double v) => v.toStringAsFixed(decimals);

  Color get pnlCol {
    if (position.points == 0) return AppColors.textSecondary;
    return position.pnlPct > 0 ? AppColors.green : AppColors.red;
  }

  Color get _statusColor {
    if (position.status == 'OPEN') return AppColors.green;
    return position.status == 'TARGET' ? AppColors.green : AppColors.red;
  }

  String get _fmtOpened {
    final t = DateTime.tryParse(position.openedAt);
    if (t == null) return '';
    final wib = t.toUtc().add(const Duration(hours: 7));
    final hh = wib.hour.toString().padLeft(2, '0');
    final mm = wib.minute.toString().padLeft(2, '0');
    return '$hh:$mm WIB';
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _PlanCell extends StatelessWidget {
  const _PlanCell({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _AdvancedScores extends StatelessWidget {
  const _AdvancedScores({required this.adv});
  final Advanced adv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ANALISIS LANJUTAN', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('MTF STACK', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              Text(adv.decompRegime, style: TextStyle(color: adv.decompRegime == 'TRENDING' ? Colors.green : Colors.amber, fontSize: 11, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${adv.regimeAlignment >= 0 ? '+' : ''}${(adv.regimeAlignment * 100).toInt()}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          _mtfScoreRow('M15', adv.mtfM15Score, adv.mtfM15Dir),
          _mtfScoreRow('M30', adv.mtfM30Score, adv.mtfM30Dir),
          _mtfScoreRow('H1', adv.mtfH1Score, adv.mtfH1Dir),
          _mtfScoreRow('H4', adv.mtfH4Score, adv.mtfH4Dir),
          _mtfScoreRow('D1', adv.mtfD1Score, adv.mtfD1Dir),
          const SizedBox(height: 10),
          _scoreRow('CONF', 'Confluence', adv.confScore),
          _scoreRow('CMP', 'Composite', adv.cmpScore),
          _scoreRow('CHR', 'Coherence', adv.chrScore),
          _scoreRow('CAL', 'Calibrated', adv.calScore),
          _scoreRow('TECH', 'Technical', adv.techScore),
          _scoreRow('UNI', 'Unified', adv.uniScore),
          const SizedBox(height: 10),
          Row(
            children: [
              _scoreBadge('CVD', '${(adv.cvdEfficiency * 100).toInt()}%', adv.cvdEfficiency > 0.5 ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              _scoreBadge('TREND', '${adv.trendConsistencyPct.toInt()}%', adv.trendConsistencyPct > 60 ? Colors.green : Colors.amber),
              const SizedBox(width: 8),
              _scoreBadge('BAR', adv.barLevel, adv.barLevel == 'STRONG' ? Colors.green : adv.barLevel == 'DEAD' ? Colors.red : Colors.amber),
              if (adv.divergence != 'NONE') ...[
                const SizedBox(width: 8),
                _scoreBadge('DIV', adv.divergence, Colors.red),
              ],
              if (adv.cvdDivergence != 'NONE') ...[
                const SizedBox(width: 8),
                _scoreBadge('FLOW', adv.cvdDivergence, Colors.red),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text('CVD & efisiensi = estimasi dari data harga harian (proxy), bukan order-flow riil.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.35)),
          if (adv.isDeadZone || adv.mlRejected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (adv.isDeadZone) _scoreBadge('DEAD ZONE', 'SKIP', Colors.red),
                if (adv.mlRejected) ...[
                  const SizedBox(width: 8),
                  _scoreBadge('ML LOW', 'REJECT', Colors.red),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreRow(String label, String sub, double score) {
    final c = score >= 70 ? Colors.green : score >= 45 ? Colors.amber : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
          Expanded(child: Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11))),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                color: c,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 32, child: Text(score.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _mtfScoreRow(String tf, int score, String dir) {
    final c = dir == 'BULLISH' ? Colors.green : dir == 'BEARISH' ? Colors.red : Colors.grey;
    final f = (score.abs() / 100.0).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(tf, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(3)),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(width: 1, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                  ),
                  Align(
                    alignment: score >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: f,
                      child: Container(
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(score >= 0 ? '+$score' : '$score', textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _VolumeProfileCard extends StatelessWidget {
  const _VolumeProfileCard({required this.inst, required this.decimals});

  final InstitutionalContext inst;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final vp = inst.vp;
    final basis = inst.basis;
    final posColor = vp != null && vp.pricePos == 'ABOVE'
        ? Colors.deepOrange
        : vp != null && vp.pricePos == 'BELOW'
            ? Colors.cyan
            : AppColors.amber;
    final posLabel = vp == null
        ? '\u2014'
        : vp.pricePos == 'ABOVE'
            ? 'DI ATAS'
            : vp.pricePos == 'BELOW'
                ? 'DI BAWAH'
                : 'DI DALAM';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VOLUME PROFILE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          if (vp == null || !vp.available)
            const Text('Belum ada data cukup untuk membangun profile.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11))
          else ...[
            Row(
              children: [
                _vpCell('POC', vp.poc!.toStringAsFixed(decimals), AppColors.purple),
                const SizedBox(width: 10),
                _vpCell('VAH', vp.vah!.toStringAsFixed(decimals), AppColors.blue),
                const SizedBox(width: 10),
                _vpCell('VAL', vp.val!.toStringAsFixed(decimals), AppColors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _vpCell('POSISI HARGA', posLabel, posColor),
                const SizedBox(width: 10),
                _vpCell('LBR AREA', '${(vp.vaWidthPct ?? 0).toStringAsFixed(1)}%', AppColors.amber),
                const SizedBox(width: 10),
                _vpCell('JARAK POC', '${(vp.pocDistPct ?? 0).toStringAsFixed(1)}%', AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: ((vp.rangePosPct ?? 0) / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.surfaceAlt,
              color: posColor,
            ),
            const SizedBox(height: 4),
            Text('posisi harga dalam rentang ${vp.lookback ?? 126} hari',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
          ],
          if (basis != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.straighten_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text('BASIS FUTUR\u2013SPOT', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const Spacer(),
                Text(
                  basis.state,
                  style: TextStyle(
                    color: basis.state == 'CONTANGO' ? AppColors.green : AppColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${basis.lastPct?.toStringAsFixed(3)}%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
            if ((basis.avg20Pct ?? 0) != 0) ...[
              const SizedBox(height: 3),
              Text('rata-rata 20 hari: ${basis.avg20Pct!.toStringAsFixed(3)}% \u00B7 hanya untuk konteks, bukan sinyal.',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _vpCell(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.pipeline});

  final PipelineStats pipeline;

  @override
  Widget build(BuildContext context) {
    final total = pipeline.tracked;
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('PIPELINE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(width: 8),
              Text('$total sinyal', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pchip('ENTRY', pct(pipeline.entryRate), pipeline.entryRate >= 0.2 ? Colors.green : Colors.amber),
              _pchip('REJECT', pct(pipeline.rejectionRate), pipeline.rejectionRate > 0.7 ? Colors.red : Colors.amber),
              _pchip('DEAD', pct(pipeline.deadZoneRate), pipeline.deadZoneRate > 0.2 ? Colors.red : Colors.grey),
              _pchip('CONF', pct(pipeline.avgConfidence), pipeline.avgConfidence >= 0.5 ? Colors.green : Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          _dirBar('BUY', pipeline.directionCounts['BUY'] ?? 0, total, AppColors.green),
          _dirBar('SELL', pipeline.directionCounts['SELL'] ?? 0, total, AppColors.red),
          _dirBar('HOLD', pipeline.directionCounts['HOLD'] ?? 0, total, AppColors.textSecondary),
          const SizedBox(height: 10),
          ...[
            'ULTIMATE',
            'APLUS',
            'A',
            'BPLUS',
            'B',
            'C',
          ].where((g) => (pipeline.gradeDistribution[g] ?? 0) > 0).map((g) => _gradeBar(g, pipeline.gradeDistribution[g] ?? 0, total)),
        ],
      ),
    );
  }

  Widget _pchip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _dirBar(String label, int n, int total, Color c) {
    final f = total > 0 ? (n / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: f, minHeight: 6, backgroundColor: AppColors.surfaceAlt, color: c),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _gradeBar(String grade, int n, int total) {
    final c = grade == 'ULTIMATE' ? Colors.amber : grade == 'APLUS' ? Colors.green : grade == 'A' ? Colors.lightGreen : grade == 'BPLUS' ? Colors.blue : Colors.cyan;
    final f = total > 0 ? (n / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text(grade, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: f, minHeight: 6, backgroundColor: AppColors.surfaceAlt, color: c),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.market});

  final Map<String, dynamic> market;

  Map<String, dynamic> _m(String key) => (market[key] as Map<String, dynamic>?) ?? const {};
  List<String> _list(String key) => (market[key] as List?)?.whereType<String>().toList() ?? const [];

  int get _dec => (market['decimals'] as num?)?.toInt() ?? 2;
  String _f(num v) => v.toStringAsFixed(_dec);
  String _pct(num v) => '${(v * 100).toStringAsFixed(0)}%';

  Color _regimeColor(String label) {
    switch (label) {
      case 'TRENDING_UP':
        return AppColors.green;
      case 'TRENDING_DOWN':
        return AppColors.red;
      case 'TEKANAN':
        return Colors.lightGreen;
      case 'PELEMAHAN':
        return Colors.orange;
      default:
        return AppColors.amber;
    }
  }

  Color _dirColor(String d) => d == 'UP' ? AppColors.green : d == 'DOWN' ? AppColors.red : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    if (market['available'] != true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(child: Text('Analisis struktur menunggu data historis yang cukup.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ],
        ),
      );
    }

    final regime = _m('regime');
    final vol = _m('volatility');
    final mom = _m('momentum');
    final div = _m('divergence');
    final conf = _m('confirmations');
    final levels = _m('levels');
    final plan = _m('plan');
    final explain = _list('explain');
    final items = (conf['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final supports = (levels['support'] as List?)?.whereType<num>().toList() ?? const [];
    final resistances = (levels['resistance'] as List?)?.whereType<num>().toList() ?? const [];
    final regimeHistory = (market['regime_history'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final regimeLabel = regime['label'] as String? ?? 'CHOPPY';
    Map<String, dynamic>? curRow;
    for (final row in regimeHistory) {
      if ((row['regime'] as String?) == regimeLabel && (row['samples'] as num? ?? 0) > 0) {
        curRow = row;
        break;
      }
    }
    final regCol = _regimeColor(regimeLabel);
    final volState = vol['state'] as String? ?? 'NORMAL';
    final volCol = volState == 'HIGH' ? Colors.orange : volState == 'LOW' ? Colors.cyan : AppColors.textSecondary;
    final momBulk = mom['bulk'] as String? ?? 'FLAT';
    final eff = (regime['efficiency'] as num?)?.toDouble() ?? 0.0;

    final agreements = (conf['agreeing'] as num?)?.toInt() ?? 0;
    final totals = (conf['total'] as num?)?.toInt() ?? 0;
    final concurrence = (conf['concurrence'] as num?)?.toDouble() ?? 0.0;
    final confCol = concurrence >= 0.7 ? AppColors.green : concurrence >= 0.5 ? AppColors.amber : AppColors.red;

    final divNote = div['note'] as String? ?? '';
    final planSide = plan['side'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 15, color: AppColors.blue),
              const SizedBox(width: 6),
              const Text('ANALISIS MENDALAM', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              const Spacer(),
              Text('EFISIENSI ${_pct(eff)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _mkChip('REGIME', regimeLabel, regCol),
              _mkChip('VOL', volState, volCol),
              _mkChip('MOM', momBulk, _dirColor(mom['direction'] as String? ?? 'NEUTRAL')),
            ],
          ),
          if ((regime['note'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(regime['note'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
          ],
          if (curRow != null) ...[
            const SizedBox(height: 10),
            _histBox(regimeLabel, regCol, curRow),
          ],
          if (divNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(divNote, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.4))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('KONFIRMASI TEKNIS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const Spacer(),
              Text('$agreements/$totals', style: TextStyle(color: confCol, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: concurrence, minHeight: 6, backgroundColor: AppColors.surfaceAlt, color: confCol),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: items.map((it) {
                final dir = it['direction'] as String? ?? 'NEUTRAL';
                final label = it['label'] as String? ?? '';
                final agree = it['agree'] == true;
                final c = _dirColor(dir);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: agree ? c.withValues(alpha: 0.15) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.withValues(alpha: agree ? 0.5 : 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dir == 'UP' ? '\u25B2' : dir == 'DOWN' ? '\u25BC' : '\u25C6', style: TextStyle(color: c, fontSize: 10)),
                      const SizedBox(width: 3),
                      Text(label, style: TextStyle(color: agree ? AppColors.textPrimary : AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mkMetric('PIVOT', _f((levels['pivot'] as num?)?.toDouble() ?? 0), AppColors.textSecondary),
              _mkMetric('SUPPORT', supports.isEmpty ? '-' : _f(supports.first), AppColors.green),
              _mkMetric('RESISTANCE', resistances.isEmpty ? '-' : _f(resistances.first), AppColors.red),
              if ((levels['distance_to_support_pct'] as num?) != null)
                _mkMetric('JARAK S', '${(levels['distance_to_support_pct'] as num).toStringAsFixed(2)}%', AppColors.green),
              if ((levels['distance_to_resistance_pct'] as num?) != null)
                _mkMetric('JARAK R', '${(levels['distance_to_resistance_pct'] as num).toStringAsFixed(2)}%', AppColors.red),
            ],
          ),
          if (planSide != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(planSide == 'BUY' ? Icons.north_rounded : Icons.south_rounded, size: 14, color: planSide == 'BUY' ? AppColors.green : AppColors.red),
                const SizedBox(width: 5),
                const Text('RENCANA HARI INI', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const Spacer(),
                if ((plan['risk_reward'] as num?) != null)
                  Text('RR ${(plan['risk_reward'] as num).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _metricCell('SL', _f((plan['sl'] as num?)?.toDouble() ?? 0), AppColors.red)),
                const SizedBox(width: 8),
                Expanded(child: _metricCell('TP1', _f((plan['tp1'] as num?)?.toDouble() ?? 0), AppColors.green)),
                const SizedBox(width: 8),
                Expanded(child: _metricCell('TP2', _f((plan['tp2'] as num?)?.toDouble() ?? 0), AppColors.green)),
              ],
            ),
          ],
          if (explain.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('BACA PASAR', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final line in explain)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u2022 ', style: TextStyle(color: AppColors.blue, fontSize: 11)),
                    Expanded(child: Text(line, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _mkChip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _mkMetric(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  Widget _metricCell(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  Widget _histBox(String label, Color col, Map<String, dynamic> row) {
    final wr = (row['win_rate'] as num?)?.toDouble() ?? 0;
    final tr = (row['total_return'] as num?)?.toDouble() ?? 0;
    final dd = (row['max_drawdown'] as num?)?.toDouble() ?? 0;
    final trades = (row['trades'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.leaderboard_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERFORMA HISTORIS REZIM $label', style: TextStyle(color: col, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(
                  'WR ${_pct(wr)} \u2022 $trades trade \u2022 return ${_pct(tr)} \u2022 DD ${(dd * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const Text('Hasil historis sinyal pada kondisi pasar seperti sekarang.', style: TextStyle(color: AppColors.textTertiary, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationPanel extends StatefulWidget {
  const _EducationPanel();

  @override
  State<_EducationPanel> createState() => _EducationPanelState();
}

class _EducationPanelState extends State<_EducationPanel> {
  bool _open = false;

  static const _rows = <(String, String)>[
    ('Regime', 'Kondisi pasar: trending (bergerak teratur) vs choppy (acak/gorak-gorok). Pahami dulu regime sebelum eksekusi.'),
    ('Efisiensi', 'Seberapa lurus pergerakan harga. Tinggi = tren konsisten; rendah = pasar sideways.'),
    ('RSI (14)', 'Ukur kekuatan momentum 0-100. Di atas 70 jenuh beli (overbought), di bawah 30 jenuh jual (oversold).'),
    ('MACD (12/26/9)', 'Selisih EMA cepat vs lambat. Histogram positif = tekanan naik, negatif = tekanan turun.'),
    ('EMA 9/21/50', 'Rata-rata bergerak. Harga di atas EMA21 = bias naik; di bawah = bias turun.'),
    ('Bollinger %B', 'Posisi harga dalam pita volatilitas. Mendekati pita bawah sering jenuh jual.'),
    ('ATR (14)', 'Rata-rata rentang harga normal per hari. Dasar penentuan stop loss dan take profit.'),
    ('Divergensi', 'Momentum (RSI/MACD) berlawanan dengan harga. Peringatan awal pembalikan arah.'),
    ('Konfirmasi teknis', 'Jumlah indikator yang searah dengan sinyal. Semakin banyak, sinyal makin kuat.'),
    ('SL/TP & RR', 'Stop loss = batas risiko, take profit = target. Rasio risiko-imbalan (RR) minimum 1:2 disarankan.'),
    ('Volatilitas', 'Aktivitas harga. Tinggi = gerakan besar (SL longgar, posisi kecil); rendah = pasar tenang.'),
    ('Momentum 20 hari', 'Perubahan harga 20 hari terakhir. Bisa menimbang "mempercepat", "melambat", atau "membalik".'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('PANEL EDUKASI BACA PASAR', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('CARA BACA SINYAL', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 12),
            for (final r in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(r.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(child: Text(r.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4))),
                  ],
                ),
              ),
            const Text('Semua angka berasal dari data harian, bukan saran trading. Verifikasi selalu dengan disiplin risiko.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
