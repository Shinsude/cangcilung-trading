part of 'package:cangcilung_trading/screens/home_screen.dart';

class _SignalPage extends StatelessWidget {
  const _SignalPage({required this.data, required this.onRefresh, required this.pulse, required this.alertTarget, required this.onSetAlert, required this.onClearAlert, this.minimal = false, this.confHistory = const [], this.history = const [], this.historyLoading = false, this.digest, this.onSelectSymbol});

  final TradingData data;
  final Future<void> Function() onRefresh;
  final AnimationController pulse;
  final double? alertTarget;
  final VoidCallback onSetAlert;
  final VoidCallback onClearAlert;
  final bool minimal;
  final List<double> confHistory;
  final List<Map<String, dynamic>> history;
  final bool historyLoading;
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
          if (!minimal && digest != null) ...[
            _DigestCard(digest: digest!, onSelect: onSelectSymbol),
            const SizedBox(height: 14),
          ],
          _PriceHero(data: data),
          if (data.dataSource != 'live') ...[
            const SizedBox(height: 8),
            _DataSourceWarning(source: data.dataSource),
          ],
          if (!minimal) ...[
            const SizedBox(height: 10),
            const _CandleTimer(),
            const SizedBox(height: 8),
            const _SessionTimeline(),
          ],
          const SizedBox(height: 14),
          _Tilt3D(
            maxTilt: 6,
            child: _SignalHero(signal: data.signal, prediction: data.prediction, price: data.currentPrice, decimals: data.decimals, pulse: pulse, advanced: data.advanced, confHistory: confHistory),
          ),
          if (!minimal) ...[
            const SizedBox(height: 14),
            _RiskPlanCard(risk: data.risk, decimals: data.decimals),
            if (data.position.open) ...[
              const SizedBox(height: 14),
              _PositionCard(position: data.position, decimals: data.decimals),
            ],
          ],
          const SizedBox(height: 14),
          _AlertBar(target: alertTarget, price: data.currentPrice, decimals: data.decimals, onSet: onSetAlert, onClear: onClearAlert),
          if (!minimal) ...[
            const SizedBox(height: 14),
            _MiniScoreboard(loading: historyLoading, entries: history),
            const SizedBox(height: 14),
            _QuickIndicators(ind: data.indicators),
            const SizedBox(height: 14),
            _AdvancedScores(adv: data.advanced),
            if (data.pipeline.tracked > 0) ...[
              const SizedBox(height: 14),
              _PipelineCard(pipeline: data.pipeline),
            ],
            const SizedBox(height: 14),
            _SystemHealthCard(system: data.system ?? const SystemHealth()),
          ],
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
        ? 'Data pasar tidak tersedia saat ini. Sinyal memakai data simulasi â€” jangan untuk trading nyata.'
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
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF101D29), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.35)),
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
              Text(digest.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.blue),
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
                      child: Text('${s.action}${s.strength.isNotEmpty ? 'Â·${s.strength}' : ''}', style: TextStyle(color: _actionColor(s.action), fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _predictionText(s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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

class _AlertBar extends StatelessWidget {
  const _AlertBar({required this.target, required this.price, required this.decimals, required this.onSet, required this.onClear});
  final double? target;
  final double price;
  final int decimals;
  final VoidCallback onSet;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final active = target != null;
    final c = active ? AppColors.amber : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.notifications_active_rounded : Icons.low_priority, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: active
                ? Text('Target ${target!.toStringAsFixed(decimals)} \u2022 Harga saat ini ${price.toStringAsFixed(decimals)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700))
                : const Text('Setel alert harga \u2022 dicek tiap 5 menit saat app aktif (best-effort, tanpa push server)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          if (active)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text('HAPUS', style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            )
          else
            GestureDetector(
              onTap: onSet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Text('SETEL', style: TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
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
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10)),
        ],
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
                child: Text(data.category.toUpperCase(), style: const TextStyle(color: AppColors.blue, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                shadows: [Shadow(color: accent.withValues(alpha: 0.35), blurRadius: 20)],
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
              child: Text('Diperbarui ${_relativeTime(data.updatedAt!)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.3)),
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
            const Text('KEYAKINAN TERAKHIR', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            Text(values.last.toStringAsFixed(3), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
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

class _Tilt3D extends StatefulWidget {
  const _Tilt3D({required this.child, this.maxTilt = 6});
  final Widget child;
  final double maxTilt;

  @override
  State<_Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<_Tilt3D> {
  double _dx = 0;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final rel = (e.localPosition - box.size.center(Offset.zero));
        setState(() {
          _dx = (rel.dx / box.size.width).clamp(-1.0, 1.0) * widget.maxTilt;
          _dy = (-rel.dy / box.size.height).clamp(-1.0, 1.0) * widget.maxTilt;
        });
      },
      onExit: (_) => setState(() {
        _dx = 0;
        _dy = 0;
      }),
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0008)
          ..rotateY(_dx * 0.0174533)
          ..rotateX(_dy * 0.0174533),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

class _SignalHero extends StatelessWidget {
  const _SignalHero({required this.signal, required this.prediction, required this.price, required this.decimals, required this.pulse, this.advanced, this.confHistory = const []});

  final Signal signal;
  final Prediction prediction;
  final double price;
  final int decimals;
  final AnimationController pulse;
  final Advanced? advanced;
  final List<double> confHistory;

  @override
  Widget build(BuildContext context) {
    final sigColor = signal.action.toSignalColor();
    final dirColor = prediction.direction.toSignalColor();
    final arrow = prediction.direction == 'UP' ? 'Ã¢â€“Â²' : prediction.direction == 'DOWN' ? 'Ã¢â€“Â¼' : 'Ã¢â€”â€ ';
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [sigColor.withValues(alpha: 0.12 + pulse.value * 0.06), AppColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: sigColor.withValues(alpha: 0.3 + pulse.value * 0.15)),
          boxShadow: [
            BoxShadow(
              color: sigColor.withValues(alpha: 0.08 + pulse.value * 0.08),
              blurRadius: 28 + pulse.value * 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
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
                  child: Text(signal.strength.toUpperCase(), style: TextStyle(color: sigColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
                GestureDetector(
                  onTap: () => _copySignal(context),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 15),
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
                        shadows: [Shadow(color: sigColor.withValues(alpha: 0.5), blurRadius: 20)],
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
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% Ã‚Â· ${prediction.horizon}',
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
      ),
    );
  }

  IconData _score2icon(double c) => c >= 0.75 ? Icons.local_fire_department_rounded : Icons.bolt_rounded;

  void _copySignal(BuildContext context) {
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;
    final text = [
      'Cangcilung Trading AI',
      'Sinyal: ${signal.action} (${signal.strength}) Â· ${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
      'Harga: ${price.toStringAsFixed(decimals)}',
      'Prediksi ${prediction.horizon}: ${prediction.direction == 'UP' ? 'naik' : prediction.direction == 'DOWN' ? 'turun' : 'netral'} â†’ ${prediction.nextPrice.toStringAsFixed(decimals)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
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
              child: Text(w, style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w700)),
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
      child: Text('$tf $dir', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sessionBadge(String session) {
    final c = session.contains('LONDON') ? Colors.green : session.contains('ASIA') ? Colors.cyan : session.contains('NEW') ? Colors.amber : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(session, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _pill(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
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

class _RiskPlanCard extends StatelessWidget {
  const _RiskPlanCard({required this.risk, required this.decimals});

  final Risk risk;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    if (!risk.available) {
      if ((risk.note ?? '').isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(risk.note!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ],
        ),
      );
    }

    final side = risk.side == 'SELL';
    final col = side ? AppColors.red : AppColors.green;
    String fmt(double v) => v.toStringAsFixed(decimals);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(side ? Icons.south_rounded : Icons.north_rounded, size: 15, color: col),
              const SizedBox(width: 6),
              const Text('Plan Entry', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const Spacer(),
              Text('RR ${risk.riskReward.toStringAsFixed(2)}', style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w800)),
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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.decimals});

  final PositionPlan position;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final sell = position.side == 'SELL';
    final col = sell ? AppColors.red : AppColors.green;
    final profit = position.pnlPct > 0;
    final pnlCol = position.points == 0 ? AppColors.textSecondary : profit ? AppColors.green : AppColors.red;
    final closed = position.status == 'STOP' || position.status == 'TARGET';

    String fmt(double v) => v.toStringAsFixed(decimals);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sell ? Icons.south_rounded : Icons.north_rounded, size: 15, color: col),
              const SizedBox(width: 6),
              const Text('POSISI SIMULASI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const Spacer(),
              _chip(position.status == 'OPEN' ? 'OPEN' : position.status, position.status == 'OPEN' ? (closed ? AppColors.amber : AppColors.green) : position.status == 'TARGET' ? AppColors.green : AppColors.red),
              const SizedBox(width: 6),
              Text(_fmtOpened, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
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
          const Text('Simulasi dari sinyal terakhir â€” bukan akun MT5 live.', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4)),
        ],
      ),
    );
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
      child: Text(text, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _QuickIndicators extends StatelessWidget {
  const _QuickIndicators({required this.ind});
  final Indicators ind;

  @override
  Widget build(BuildContext context) {
    final rsiColor = ind.rsi.value < 30
        ? AppColors.green
        : ind.rsi.value > 70
            ? AppColors.red
            : AppColors.amber;
    final macdColor = ind.macd.histogram >= 0 ? AppColors.green : AppColors.red;
    final emaColor = ind.ema.trend == 'bullish' ? AppColors.green : AppColors.red;

    return Row(
      children: [
        Expanded(child: _MiniIndicator(label: 'RSI', value: ind.rsi.value.toStringAsFixed(1), sub: ind.rsi.region, color: rsiColor)),
        const SizedBox(width: 8),
        Expanded(child: _MiniIndicator(label: 'MACD', value: ind.macd.histogram.toStringAsFixed(4), sub: ind.macd.cross ?? 'neutral', color: macdColor)),
        const SizedBox(width: 8),
        Expanded(child: _MiniIndicator(label: 'EMA', value: ind.ema.trend, sub: '', color: emaColor)),
      ],
    );
  }
}

class _MiniIndicator extends StatelessWidget {
  const _MiniIndicator({required this.label, required this.value, required this.sub, required this.color});

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
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
              const Text('MTF STACK', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              Text(adv.decompRegime, style: TextStyle(color: adv.decompRegime == 'TRENDING' ? Colors.green : Colors.amber, fontSize: 10, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${adv.regimeAlignment >= 0 ? '+' : ''}${(adv.regimeAlignment * 100).toInt()}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
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
            ],
          ),
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
          Expanded(child: Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10))),
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
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
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
              Text('$total sinyal', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
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
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _dirBar(String label, int n, int total, Color c) {
    final f = total > 0 ? (n / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: f, minHeight: 6, backgroundColor: AppColors.surfaceAlt, color: c),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800))),
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
          SizedBox(width: 42, child: Text(grade, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: f, minHeight: 6, backgroundColor: AppColors.surfaceAlt, color: c),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
