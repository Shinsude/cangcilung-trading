part of 'package:cangcilung_trading/screens/home_screen.dart';

class _SignalPage extends StatelessWidget {
  const _SignalPage({required this.data, required this.onRefresh, required this.alertTarget, required this.onSetAlert, required this.onClearAlert, this.confHistory = const [], this.history = const [], this.historyLoading = false, this.historyError = false, this.onRetryHistory, this.digest, this.onSelectSymbol, this.forward});

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
  final Map<String, dynamic>? forward;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SignalHero(signal: data.signal, prediction: data.prediction, price: data.currentPrice, decimals: data.decimals, advanced: data.advanced, confHistory: confHistory),
          const SizedBox(height: 14),
          _PriceHero(data: data),
          if (data.dataSource != 'live') ...[
            const SizedBox(height: 8),
            _DataSourceWarning(source: data.dataSource),
          ],
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
          if (forward != null) ...[
            const SizedBox(height: 14),
            _ForwardTestCard(body: forward!),
          ],
          const SizedBox(height: 14),
          _MiniScoreboard(loading: historyLoading, entries: history, hasError: historyError, onRetry: onRetryHistory),
          const SizedBox(height: 14),
          _DetailSection(
            children: [
              const _CandleTimer(),
              const _SessionTimeline(),
              _IndicatorBlock(ind: data.indicators, vp: data.institutional?.vp, decimals: data.decimals),
              if (data.institutional != null) _VolumeProfileCard(inst: data.institutional!, decimals: data.decimals),
              if (data.institutional?.smc != null && data.institutional!.smc!.available) _SmcCard(smc: data.institutional!.smc!, decimals: data.decimals),
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

class _ForwardTestCard extends StatelessWidget {
  const _ForwardTestCard({required this.body});

  final Map<String, dynamic> body;

  int get _minResolved => (body['min_resolved'] as num?)?.toInt() ?? 20;

  String _fmt(num? v, {int d = 2}) => v == null ? '\u2014' : v.toStringAsFixed(d);

  Color _verdictColor(String v) {
    switch (v) {
      case 'layak-lanjut':
        return AppColors.green;
      case 'evaluasi-gagal':
        return AppColors.red;
      default:
        return AppColors.amber;
    }
  }

  String _label(String v) => v == 'layak-lanjut' ? 'LAYAK LANJUT' : v == 'evaluasi-gagal' ? 'EVALUASI GAGAL' : 'MENUNGGU DATA';

  String _tfLabel(String name) => name == '60m' ? '60M' : name.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final logs = (body['logs'] as Map<String, dynamic>?) ?? const {};
    final params = (body['params'] as Map<String, dynamic>?) ?? const {};
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_rounded, size: 15, color: AppColors.purple),
              SizedBox(width: 8),
              Text('FORWARD TEST', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Spacer(),
              Text('paper', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            params.isEmpty
                ? 'Eksperimen forward-test strategi limit-entry SMC.'
                : 'swing ${params['swing']} \u00B7 zone ${params['zone_bars']} bar \u00B7 SL ${params['sl_bars']} bar \u00B7 retest ${params['retest_bars']} bar \u00B7 RR ${params['rr']}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final e in logs.entries) _logRow(name: e.key, v: (e.value as Map<String, dynamic>?)),
          const SizedBox(height: 8),
          const Text('Eksperimen untuk pemantauan, bukan rekomendasi trading.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _logRow({required String name, required Map<String, dynamic>? v}) {
    final err = v == null ? null : v['error'];
    final vrd = v?['verdict'] as String? ?? 'menunggu-data';
    final vc = _verdictColor(vrd);
    final nRes = (v?['n_resolved'] as num?)?.toInt() ?? 0;
    final win = (v?['win_rate_decided'] as num?);
    final pf = (v?['profit_factor'] as num?);
    final avgR = (v?['avg_r'] as num?);
    final rows = (v?['rows'] as num?) ?? 0;
    final remaining = _minResolved - nRes;
    final progress = (nRes / _minResolved).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(_tfLabel(name), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: vc.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
                child: Text(_label(vrd), style: TextStyle(color: vc, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: err != null
                    ? Text(err, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('$nRes/$_minResolved resolved', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                          if (win != null) Text('win ${_fmt(win)}%', style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700)),
                          if (pf != null) Text('PF ${_fmt(pf, d: 3)}', style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w700)),
                          if (avgR != null) Text('R ${_fmt(avgR)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                          Text('$rows baris', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10.5)),
                        ],
                      ),
              ),
            ],
          ),
          if (err == null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.surfaceAlt,
                color: vc,
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 3),
              Text('Butuh $remaining sinyal selesai lagi menuju evaluasi (ambang $_minResolved).',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10.5, height: 1.3)),
            ],
          ],
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
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: -0.5,
                height: 1.05,
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
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final act = _TabActive.of(context);
    if (act == _active) return;
    _active = act;
    if (act) {
      _t?.cancel();
      _t = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _t?.cancel();
      _t = null;
    }
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
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surfaceAlt],
          ),
          border: Border.all(color: sigColor.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: sigColor.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill('MTF', '${adv.mtfAlignment >= 0 ? '+' : ''}${(adv.mtfAlignment * 100).toInt()}%', adv.mtfAlignment > 0.3 ? Colors.green : adv.mtfAlignment < -0.3 ? Colors.red : Colors.grey),
            _pill('REGIME', adv.regime, regimeColor),
            _pill('GRADE', adv.grade, _gradeColor(adv.grade)),
            _sessionBadge(adv.session),
            if (adv.smcWarning)
              _pill('SMC', 'WARN', Colors.orange),
          ],
        ),
        if (adv.weaknesses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: adv.weaknesses.take(2).map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(w, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
            )).toList(),
          ),
        ],
      ],
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
                const Text('BASIS FUTUR\u2013FISIK', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const Spacer(),
                Text(
                  basis.state,
                  style: TextStyle(
                    color: basis.state == 'PREMIUM'
                        ? AppColors.green
                        : basis.state == 'DISKONTO'
                            ? AppColors.red
                            : AppColors.amber,
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
              Text('premium/diskonto vs fisik (GLD) \u00B7 rata-rata 20 hari: ${basis.avg20Pct!.toStringAsFixed(3)}% \u00B7 hanya untuk konteks, bukan sinyal.',
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

class _SmcZoneRow extends StatelessWidget {
  const _SmcZoneRow({required this.label, required this.zone, required this.color, required this.decimals, this.showVol = false});

  final String label;
  final SmcZone? zone;
  final Color color;
  final int decimals;
  final bool showVol;

  @override
  Widget build(BuildContext context) {
    final zoneOk = zone != null && zone!.available;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
          const Spacer(),
          if (showVol && zoneOk && zone!.volumeStrong == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
              child: Text('VOL ${zone!.volRatio?.toStringAsFixed(1) ?? ''}x', style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
            ),
          if (zoneOk) const SizedBox(width: 6),
          if (!zoneOk)
            const Text('\u2014', style: TextStyle(color: AppColors.textTertiary, fontSize: 11))
          else
            Text(
              '${zone!.top!.toStringAsFixed(decimals)} \u2022 ${zone!.bottom!.toStringAsFixed(decimals)}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          const SizedBox(width: 6),
          if (zoneOk && zone!.ageDays != null)
            Text('${zone!.ageDays}d', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SmcCard extends StatelessWidget {
  const _SmcCard({required this.smc, required this.decimals});

  final SmartMoneyContext smc;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final st = smc.structure;
    final trendColor = st.trend == 'BULLISH'
        ? Colors.green
        : st.trend == 'BEARISH'
            ? Colors.red
            : Colors.grey;
    final pdPos = smc.premiumDiscount.pos;
    final pdColor = pdPos == 'PREMIUM'
        ? Colors.deepOrange
        : pdPos == 'DISKONTO'
            ? Colors.cyan
            : Colors.grey;
    final biasColor = smc.bias.contains('BULLISH')
        ? Colors.green
        : smc.bias.contains('BEARISH')
            ? Colors.red
            : Colors.grey;

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
              const Text('SMART MONEY (SMC)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: biasColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_biasLabel(smc.bias), style: TextStyle(color: biasColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('TREND', st.trend, trendColor),
              const SizedBox(width: 8),
              if (st.breakout != null)
                _chip('BREAK', st.breakout == 'BULLISH' ? '${st.breakoutType ?? ''} \u00B7 UP' : '${st.breakoutType ?? ''} \u00B7 DOWN', st.breakout == 'BULLISH' ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              _chip('PREM/DISC', pdPos, pdColor),
            ],
          ),
          if (st.swingHigh != null || st.swingLow != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _levelCell('SWING HIGH', st.swingHigh, '${st.swingHighBarsAgo ?? 0} bar', Colors.green, decimals)),
                const SizedBox(width: 8),
                Expanded(child: _levelCell('SWING LOW', st.swingLow, '${st.swingLowBarsAgo ?? 0} bar', Colors.red, decimals)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Text('FAIR VALUE GAP (UNMITIGATED)', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          _SmcZoneRow(label: 'BULLISH', zone: smc.bullishFvg, color: Colors.green, decimals: decimals),
          _SmcZoneRow(label: 'BEARISH', zone: smc.bearishFvg, color: Colors.red, decimals: decimals),
          const SizedBox(height: 10),
          const Text('ORDER BLOCK (EST.)', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          _SmcZoneRow(label: 'DEMAND (BUY)', zone: smc.bullishOb, color: Colors.green, decimals: decimals, showVol: true),
          _SmcZoneRow(label: 'SUPPLY (SELL)', zone: smc.bearishOb, color: Colors.red, decimals: decimals, showVol: true),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              const Text('LIKUIDITAS (PDH/PDL)', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const Spacer(),
              Text(_sweepLabel(smc.liquidity.sweep, smc.liquidity.confirmation),
                  style: TextStyle(
                    color: _sweepColor(smc.liquidity.sweep, smc.liquidity.confirmation),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          if (smc.liquidity.pdh != null || smc.liquidity.pdl != null) ...[
            const SizedBox(height: 4),
            Text(
              'PDH ${smc.liquidity.pdh?.toStringAsFixed(decimals) ?? '\u2014'} \u2022 PDL ${smc.liquidity.pdl?.toStringAsFixed(decimals) ?? '\u2014'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            ),
            child: Text(
              smc.note.isEmpty
                  ? 'Estimasi Smart Money dari data harian, bukan order-flow intraday.'
                  : smc.note,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label $value', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _levelCell(String label, double? value, String sub, Color color, int decimals) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            value == null ? '\u2014' : value.toStringAsFixed(decimals),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9)),
        ],
      ),
    );
  }

  String _biasLabel(String bias) {
    switch (bias) {
      case 'LEAN_BULLISH':
        return 'CENDERUNG BULLISH';
      case 'LEAN_BEARISH':
        return 'CENDERUNG BEARISH';
      default:
        return 'NETRAL';
    }
  }

  String _sweepLabel(String sweep, String confirmation) {
    final base = switch (sweep) {
      'BUY_SWEEP' => 'SWEEP BAWAH (BULLISH)',
      'SELL_SWEEP' => 'SWEEP ATAS (BEARISH)',
      'BOTH' => 'SWEEP KEDUA ARAH',
      _ => 'TIDAK ADA SWEEP',
    };
    return switch (confirmation) {
      'CONFIRMED' => '$base - TERKONFIRMASI',
      'PENDING' => '$base - BELUM KONFIRM',
      _ => base,
    };
  }

  Color _sweepColor(String sweep, String confirmation) {
    if (sweep == 'NONE') return AppColors.textTertiary;
    if (confirmation == 'CONFIRMED') return sweep == 'BUY_SWEEP' ? Colors.green : Colors.red;
    if (confirmation == 'PENDING') return AppColors.amber;
    return AppColors.textSecondary;
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
  int _topic = 0;

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

  static const _rowsSM = <(String, String)>[
    ('Siapa mereka', 'Trader institusional: profesional bervolume besar atas nama institusi (bank investasi, hedge fund, dana pensiun, manajer aset, ETF). Uang milik nasabah, bukan pribadi; disebut juga \u201cSmart Money\u201d.'),
    ('vs Trader retail', 'Skala: miliaran dolar vs modal pribadi \u2014 gerak mereka saja bisa menggeser harga. Tujuan: return tahunan konsisten vs untung cepat. Akses: order flow & terminal makro vs data publik. Produk: swaps, forwards, IPO vs spot.'),
    ('VWAP / TWAP', 'Eksekusi raksasa dipecah kecil sepanjang hari untuk rata-rata harga terbaik tanpa mengguncang pasar.'),
    ('Arbitrase', 'Ambil selisih harga aset yang sama di bursa berbeda, mengandalkan kecepatan teknologi.'),
    ('StatArb', 'Cari penyimpangan korelasi historis antar aset lewat model statistik untuk profit.'),
    ('Bacaan SMC', 'Jejak mereka terlihat di likuiditas (di luar level penting), break of structure + order block, dan FVG. Panel SMC di aplikasi ini mengukur versi modular dari jejak itu.'),
  ];

  static const _rowsEO = <(String, String)>[
    ('Buy-side & sell-side', 'Buy-side = pemilik dana (manajer investasi, hedge fund, dana pensiun); PM memutuskan, trader buy-side mengeksekusi. Sell-side = bank investasi & broker-dealer penyedia likuiditas & eksekusi.'),
    ('1. Keputusan investasi', 'PM/analis putuskan beli/jual berdasar riset, alokasi portofolio & mandat klien: apa yang dibeli, berapa besar, timeframe, benchmark eksekusi (VWAP, arrival price, limit). Masih intent / parent order, bukan order final.'),
    ('2. Order ticket & OMS', 'Parent order masuk OMS (Order Management System): simbol, sisi, kuantitas, tipe order (limit/market/VWAP/TWAP/POV), batas harga, akun klien, benchmark & urgensi.'),
    ('3. Pre-trade compliance', 'Cek otomatis sebelum keluar: mandat klien, restricted list, position limit/exposure, kas/margin, short locate (bila jual), regulasi (MiFID II, best execution). Lolos \u2192 kirim ke EMS.'),
    ('4. Strategi eksekusi', 'High-touch (sales trader manusia: block trade, IOI, RFQ) untuk order besar/ilikuid; low-touch (algo VWAP/TWAP/POV/IS/Liquidity Seeking) untuk likuid. Tentukan venue: lit, dark pool, OTC.'),
    ('5. Routing & SOR', 'EMS kirim via protokol FIX ke broker/algo. Parent order dipecah jadi banyak child order; Smart Order Router menyalurkan tiap child ke lit, dark pool/ATS, internalizer, atau venue OTC.'),
    ('6. Masuk market', 'Child order masuk matching engine: limit, market, IOC/FOK, hidden/iceberg, pegged. Lit dicocokkan price-time priority di order book; dark pool tanpa ditampilkan; obligasi/FX/derivatif lewat RFQ ke dealer.'),
    ('7. Fill & monitoring', 'Setiap fill mengirim execution report ke broker \u2192 EMS/OMS. Trader pantau harga rata-rata, slippage, market impact, sisa kuantitas; algoritma lanjut sampai penuh atau batas waktu.'),
    ('8. Post-trade & TCA', 'Alokasi hasil ke akun klien, konfirmasi & clearing, settlement T+1/T+2, lalu TCA (Transaction Cost Analysis) membandingkan harga eksekusi vs benchmark. Rekonsiliasi & laporan ke klien/regulator.'),
    ('Contoh nyata', 'PM beli 2.000.000 saham BBCA: parent order \u2192 compliance lolos \u2192 algo VWAP 20% POV \u2192 dipecah ratusan child \u2192 SOR kirim ke bursa + dark pool \u2192 tiap fill kembali ke OMS \u2192 alokasi & TCA.'),
    ('Jejak di chart', 'Volume besar tapi harga rata = absorption; order besar lalu hilang = iceberg (spoofing ilegal); gerak pelan konsisten = algoritma bekerja; block di luar bursa = kesepakatan institusi.'),
    ('Catatan', 'Alur tak selalu linear: algoritma adaptif, high-touch bisa negosiasi, order bisa dibatalkan/diubah di tengah jalan. Itulah perjalanan order institusional dari keputusan BUY sampai masuk market.'),
  ];

  static const _rowsPA = <(String, String)>[
    ('Prinsip sama', 'Parent order \u2192 risk check \u2192 algo/high-touch \u2192 child order \u2192 venue \u2192 fill \u2192 settlement \u2192 TCA. Yang beda antar-aset: venue dan mekanismenya.'),
    ('XAUUSD (gold)', 'OTC tanpa bursa terpusat: likuiditas dari bank besar, ECN, & London (LBMA); ada juga futures COMEX. Butuh prime brokerage (PB) untuk kredit. High-touch = RFQ/block ke bank (HSBC, JPM, UBS); low-touch = algo ke EBS, LMAX, Currenex, FXall. Last look bisa menolak order dalam milidetik. Settlement T+2 Loco London.'),
    ('AUDUSD (FX)', 'OTC terdesentralisasi: likuiditas bank, hedge fund, korporasi, ECN; kredit via FX prime brokerage. RFQ ke Citi/Deutsche/Barclays atau algo ke EBS, LMAX, Currenex, Hotspot, FXall. SOR pilih ECN terbaik; child bisa hidden/iceberg; last look sering. Settlement T+2 via CLS/bilateral. Paling likuid setelah EURUSD/USDJPY/GBPUSD.'),
    ('NASDAQ', 'Indeks, bukan aset langsung. Yang diperdagangkan: futures NQ (CME Globex), ETF QQQ & saham Nasdaq (bursa lit + dark pool, T+1), atau CFD retail. Future: margin via FCM, block di CME, matching engine terpusat tanpa last look, mark-to-market harian. Block saham lewat upstairs/RFQ.'),
    ('Ringkasan', 'Venue utama: ECN/bank/LBMA (gold), ECN FX (AUDUSD), Globex/bursa saham (NASDAQ). Settlement: T+2 Loco London / T+2 CLS / T+1-harian. Algo umum: VWAP-TWAP-RFQ (gold), TWAP-VWAP-POV (FX), VWAP-TWAP-IS (ekuitas). Last look hanya di OTC.'),
    ('Relevansi app', 'Aplikasi fokus XAUUSD (spot). Sinyal dihitung dari data harga harian \u2014 proxy & simulasi (bukan order flow, bukan CFD B-book). Tujuannya belajar membaca jejak institusi, bukan mengklaim eksekusi otomatis.'),
  ];

  static const _rowsOP = <(String, String)>[
    ('Fondasi legal', 'Emas institusional di RI: OJK via POJK 17/2024 Bulion (modal min Rp14 triliun utk emas fisik) vs Bappebti (Perba 4 & 13/2019, jaminan 1:1 utk pedagang emas digital di bursa berjangka). Buy-side ke pasar global butuh entitas hukum internasional (Singapura, Inggris, Cayman) utk akses prime broker.'),
    ('Prime brokerage', 'PB/PoP (ADSS, Marex) = satu pintu ke likuiditas Tier-1 bank (StanChart, NatWest), non-bank HFT, ECN. Agregasi jadi satu harga executable; smart order routing anonim; cross-margining efisien. Butuh dokumen legal, audit, profil risiko, dan credit line.'),
    ('Tumpukan teknologi', 'Backend Python + data tick MT5/API broker; API layer Flask utk siaran data/alert; execution FIX API ke broker/ECN (standar institusi); risk engine TERPISAH dari logika sinyal \u2014 daily loss limit, max drawdown, position sizing otomatis.'),
    ('Strategi SMC', 'Membaca jejak institusi: order block, liquidity sweep (jebakan SL ritel), FVG. Model auction gold: akumulasi Asia \u2192 manipulasi London \u2192 distribusi NY \u2014 trading hanya setelah sweep + displacement + dukungan VWAP. XGBoost dipakai memfilter setup (bukan prediksi arah); validasi Walk-Forward anti-overfit.'),
    ('Risiko & eksekusi', 'Pecah order: VWAP/TWAP. Filter spread: batalkan/delay saat spread lebar (alpha terlindungi dari slippage). Ukuran posisi dinamis berbasis ATR. Failsafe berlapis: daily loss limit ~3%, max drawdown ~10%, news filter.'),
    ('Siklus lengkap', 'Hukum & regulasi \u2192 konektivitas likuiditas (PB) \u2192 arsitektur teknologi \u2192 logika strategi (SMC) \u2192 manajemen risiko & eksekusi (TCA). Prioritas bukan profit strategi, tapi keandalan infrastruktur dan disiplin risiko.'),
  ];

  static const _rowsIM = <(String, String)>[
    ('Alur kerja', 'OpenCode jadi orkestrator: MCP Server MT5 (data live + eksekusi), MCP Gold (analisis makro), modul strategi (SMC/VWAP), modul risiko & eksekusi. Agent membaca proyek, menulis/men-debug/menjalankan sistem.'),
    ('Hubungkan MT5', 'Instal metatrader-mcp-server; jalankan dengan kredensial akun (login, password, server, path terminal64.exe, port). Daftarkan di opencode.json sbg MCP remote (url 127.0.0.1:9090/sse). Verifikasi: cek daftar MCP server \u2014 status connected.'),
    ('Intelijen data', 'Data harga saja tak cukup: MCP gold memberi DXY, US10Y/02Y, SPX, VIX, korelasi emas, musiman, multi-timeframe, deteksi regime. Alternatif: modul Python ke TickDB/Commodities-API untuk kontrol penuh.'),
    ('Strategi & eksekusi', 'Kode SMC (order block, liquidity sweep, FVG) dari OHLCV MT5. Eksekusi pecah parent jadi child order (VWAP sepanjang hari, filter spread otomatis). Alur: sinyal \u2192 parent \u2192 VWAP pecah child \u2192 MT5 via MCP \u2192 fill kembali utk manajemen posisi.'),
    ('Risk & backtest', 'Risk engine independen: pre-trade check (margin, exposure, sizing), ATR dynamic sizing, daily loss 3%, max drawdown 10%, news filter. Validasi: VectorBT + Walk-Forward Optimization anti-overfit; laporan QuantStats.'),
    ('Deploy & audit', 'VPS utk uptime 24/7, dashboard monitoring, audit trail append-only (tamper-evident) \u2014 mis. SYNX-MT5-MCP. OpenCode = pusat komando: kode, eksekusi, monitoring dalam satu proyek.'),
    ('Peta fase', '5 fase institusional (kepatuhan \u2192 likuiditas \u2192 teknologi \u2192 strategi \u2192 risiko) dipecah OpenCode jadi 6 langkah teknis: MT5 MCP \u2192 intelijen data \u2192 strategi & eksekusi \u2192 risiko berlapis \u2192 backtest & validasi \u2192 deploy & monitoring.'),
    ('Iteratif', 'Fase-fase iteratif, bukan linear kaku: boleh kembali ke fase lebih awal saat ada perbaikan strategi atau risiko. Verifikasi & audit terus berjalan di tiap siklus.'),
  ];

  static const _rowsMT = <(String, String)>[
    ('Arsitektur', 'OpenCode \u2192 MCP server (SSE/REST atau STDIO) \u2192 Python API \u2192 MT5 terminal \u2192 broker/market. Prasyarat: Python 3.10+, MT5 berjalan di Windows, akun MT5 (demo/live), OpenCode dengan dukungan MCP.'),
    ('Install MCP', 'pip install metatrader-mcp-server (paling mudah) \u2192 atau SYNX-MT5-MCP untuk 68+ tools + pre-flight risk, credential vault (OS keyring), drawdown circuit breaker, audit trail kriptografis (git clone lalu pip install -e .).'),
    ('Aktifkan algo', 'Langkah paling sering terlewat: Tools \u2192 Options \u2192 Expert Advisors \u2192 centang "Allow algorithmic trading"; tombol AutoTrading di toolbar harus hijau. Bila pakai EA, centang juga "Allow DLL imports".'),
    ('Jalankan MCP', 'STDIO utk lokal: --login --password --server --transport stdio. HTTP/SSE utk remote: tambah --path "path terminal64.exe" --host 0.0.0.0 --port 9090. Sukses = log "Uvicorn running on 0.0.0.0:9090". MT5 harus jalan dulu.'),
    ('Konfig OpenCode', 'opencode.json: type "remote" + url 127.0.0.1:9090/sse (SSE), atau type "local" + command/environment (STDIO). Verifikasi via cek daftar MCP: "metatrader connected". Simpan kredensial di env/vault, jangan di file.'),
    ('Simbol XAUUSD', 'Jangan hardcode "XAUUSD": 230+ broker punya 44 varian nama (XAUUSD, GOLD, XAUUSDm/c, XAUUSD.m, GOLD_USD). Kontrak: 1 lot = 100 oz, tick 0.01; harga naik 1 USD = P/L 100 USD per lot. Hitung risiko dalam USD, bukan pips \u2014 spread 0.30 bukan 3 pips.'),
    ('Keamanan', 'Batasi server ke 127.0.0.1 (bukan 0.0.0.0) bila sekelas; audit trail append-only; capability level read_only \u2192 analyst \u2192 executor \u2192 full (mulai read_only); human-in-the-loop utk order besar/ekstrem; vet kode sumber MCP sebelum instal.'),
    ('Troubleshoot', '"initialize() failed" = MT5 tak berjalan (+cek --path); "No data returned" = jaringan/server broker; "Trading is not enabled" = aktifkan algoritmik trading; "Symbol not found" = cek Market Watch  Specification; "MCP Connection Lost" = restart sesi & cek port 9090.'),
  ];

  static const _rowsDATA = <(String, String)>[
    ('Kenapa makro?', 'Emas didorong 4 pilar: Dolar (DXY, korelasi negatif \u2248 -0.63), suku bunga riil TIPS (-0.82, inverse terkuat), risiko pasar (VIX positif \u2014 safe haven), likuiditas global (positif). Tanpa konteks ini sinyal teknikal rawan false signal \u2014 misal sinyal BUY tepat saat DXY rally kuat.'),
    ('Gold-MCP', 'Rekomendasi utama; free tier fungsional (13 tools): get_gold_price, get_gold_ohlcv, get_macro_context (DXY, US10Y/02Y, SPX, VIX, BTC, silver, oil), get_gold_correlations, get_gold_seasonality, gold_market_snapshot. Instal: pip install gold-mcp; adapter MT5 BYOK: gold-mcp[mt5].'),
    ('xaudaily', 'MCP zero-dependency (standard library saja): COMEX gold + Au99.99 Shanghai, US CPI/core PCE/NFP/PPI, DXY, Treasury 10Y/30Y, VIX, SPDR holdings, FOMC odds, IMF gold buying, crude, US debt, gold driver score. Tiap field bawa source + asOf/stale flag. Update 2x/hari \u2014 daily readings, bukan tick.'),
    ('FXMacroData', 'Data makro historis + COT positioning (CFTC): release_calendar, indicator_query (CPI/NFP/PCE), cot_data, commodities, forex, market_sessions. Data USD 90 hari gratis tanpa API key: uvx mcp-server-fxmacrodata.'),
    ('Arsitektur data', 'Kombinasi, bukan satu sumber: MT5 (live & eksekusi, real-time) + Gold-MCP (konteks makro on-demand) + xaudaily (brief harian CPI/NFP/FOMC) + FXMacroData (COT + kalender rilis, mingguan/harian). Verifikasi silang minimal 2 sumber independen.'),
    ('Filter makro', 'Sebelum eksekusi BUY: DXY tak rally >0.5%/hari; US10Y tak melonjak tajam; VIX tak rendah ekstrem (risk-on). Musiman: bulan bearish \u2192 kecilkan/lewati. Regime korelasi (Gold-MCP Pro): deteksi decoupling DXY-Emas \u2014 saat ter-decouple, sinyal teknikal lebih layak dipercaya.'),
    ('Event risk', 'release_calendar utk menghindari CPI/NFP/FOMC: tidak trading (atau kurangi ukuran) di sekitar rilis besar. Contoh: sweep SMC + DXY turun + US10Y turun + VIX naik + musiman bullish + 4 jam tanpa rilis \u2192 eksekusi penuh; filter gagal \u2192 lewati atau ukuran dikurangi 50%.'),
    ('Verifikasi', 'Checklist: semua MCP connected (cek daftar MCP); get_macro_context / get_gold_seasonality / get_gold_correlations / release_calendar berfungsi; korelasi silang minimal dua sumber; filter makro terintegrasi ke logika strategi (minimal sebagai konsep).'),
  ];

  static const _rowsST = <(String, String)>[
    ('Filosofi', 'Retail menembak market order; institusi membaca jejak likuiditas & ketidakseimbangan order. Otak = sinyal SMC; tangan = eksekusi VWAP/TWAP + filter spread + proteksi slippage. Struktur: strategy/ (detector, sweep, sesi, sinyal), execution/ (VWAP, TWAP, spread, router), risk/, data/.'),
    ('SMC: swing & OB', 'Dasar SMC = swing high/low (lookback N candle). Order Block = candle berlawanan arah terakhir sebelum displacement (body > ATR x1.5), bertindak sbg support/resistance dinamis. Pakai default wajar (lookback 5-10); jangan over-optimasi parameter.'),
    ('SMC: FVG & struktur', 'Fair Value Gap = ketidakseimbangan 3 candle berturut-turut (gap), harga cenderung mengisinya sebelum lanjut tren. BOS = tembus swing searah tren (konfirmasi lanjut); CHoCH = tembus berlawanan tren (sinyal potensi reversal).'),
    ('Liquidity sweep', 'Harga menyapu SL ritel di atas swing high / di bawah swing low, lalu close kembali dalam N candle = jebakan likuiditas. Setup terbaik: London sweeping akumulasi Asia, lalu New York melanjutkan tren.'),
    ('Sesi & generator', 'Asia (07-15 WIB): hindari entry, observasi range. London (15-23): window sweep. London-NY overlap (20-23): window tren. Sinyal = sweep + bias struktur + filter makro + musiman + event risk; entry OB-mid, SL di luar OB, TP RR 1:3, confidence naik bila ada FVG.'),
    ('VWAP executor', 'Pecah parent order jadi child sesuai profil volume historis per menit (fallback TWAP). Kirim selisih target vs tereksekusi (shortfall); interval ~30 dtk; participation maks ~15%; deviation maks 20 poin; magic id unik; filling IOC; spread dicek sebelum tiap child.'),
    ('Spread filter', 'Tolak eksekusi bila spread > 0.30 (normal) / 0.60 (volatil; deteksi via ATR 2x rata-rata). Pantau hist spread: tolak bila melebar kuat vs rata-rata 10 terakhir. Router: order kecil (<0.10 lot) = market langsung; besar = VWAP.'),
    ('Kesalahan umum', 'Over-optimasi lookback swing; backtest tanpa spread (0.30 normal, 1.00+ saat news) = ilusi profit; market order utk ukuran besar; tanpa filter sesi (Asia banyak false signal); abaikan slippage (selalu set deviation & monitor).'),
  ];

  static const _rowsRK = <(String, String)>[
    ('Filosofi', 'Institusi bertanya "berapa bisa rugi sebelum berhenti", bukan "berapa bisa untung". Risk first, profit second; defense in depth (tak ada satu lapisan pun jadi single point of failure); risiko diukur kuantitatif, bukan feeling. Retail: "rasa aman 0.10 lot" vs institusi: formula.'),
    ('Sizing (ATR)', 'Ukuran selalu dari jarak SL, bukan feeling: Volume = (Equity x risk%) / (SL distance x value/point). Contoh equity 10k, risk 1% = 100, SL 5, value 100/lot \u2192 0.20 lot. SL dinamis = ATR x 1.5; ATR >1.5x rata2 \u2192 \u00d70.7, >2x \u2192 \u00d70.5, <0.7x \u2192 +20%. Bulatkan ke volume step.'),
    ('Daily limits', 'Stop bila daily loss -\u22653% atau profit +\u22656% (kunci profit), maks 10 trade/hari. State disimpan ke file agar survive restart \u2014 jangan reset tiap restart.'),
    ('Drawdown guard', 'Circuit breaker 4 level: DD <5% normal (multiplier 1.0); 5-10% \u2192 x0.75; 10-15% \u2192 x0.5; 15-20% \u2192 stop trading; >20% \u2192 full shutdown.'),
    ('Correlation', 'Risiko agregat, bukan per posisi: XAU-XAG 0.85, XAU-XPT 0.70, XAU-AUD 0.55, XAU-DXY -0.63, XAU-US10Y -0.82. Maks eksposur terkorelasi ~5% equity. Tiga posisi BUY emas-perak-platinum = satu posisi besar, bukan diversifikasi.'),
    ('News filter', 'Blokir trading 15 menit sebelum & sesudah high-impact XAUUSD: FOMC/Fed rate, NFP, CPI, PPI, core PCE, GDP, unemployment, pidato Powell, retail sales, ISM PMI. Hitung menit ke event berikutnya utk menyesuaikan ukuran.'),
    ('Kill switch', 'Emergency stop manual/otomatis untuk langsung menutup semua posisi (deviation ~50, magic khusus, comment KILL_SWITCH). Wajib ada \u2014 saat bug atau kondisi ekstrem, Anda butuh tombol darurat.'),
    ('Recovery', 'Setelah DD >15%: pemulihan bertahap \u2014 fase 1 size x0.25 (syarat 10 trade, winrate \u22650.5) \u2192 x0.5 (20 trade) \u2192 x0.75 (20 trade, WR \u22650.55) \u2192 x1.0 penuh. Mencegah revenge trading pasca rugi.'),
    ('Orkestrasi', 'Risk engine dipanggil OrderRouter SEBELUM order dikirim; strategi hanya mengirim sinyal. Alur: kill switch \u2192 daily limit \u2192 drawdown \u2192 news \u2192 korelasi \u2192 sizing \u2192 multiplier (DD x recovery x volatilitas). Kesalahan umum: fixed lot, abaikan ATR, state tak disimpan, risk menyatu dgn strategi, tanpa kill switch, full size langsung pasca DD.'),
  ];

  static const _rowsBT = <(String, String)>[
    ('Filosofi', 'Tiga pertanyaan: edge nyata? bertahan di semua regime? cukup besar setelah biaya? Jebakan retail: backtest tanpa spread (+30-50% profit ilusi), overfitting, slippage, look-ahead, survivorship, curve fitting, tanpa walk-forward, abai swap overnight.'),
    ('Framework & data', 'VectorBT (vectorized, cepat, grid search + QuantStats) utk eksplorasi; Backtrader/custom engine utk event-driven realistis (SMC + child order VWAP). Data terbaik: tick/M1 dari MT5 broker sendiri (spread asli); alternatif Dukascopy/HistData/Tickstory. Cek kualitas: gap, spread 0.2-0.5, UTC, duplikasi, cakup 2020 COVID & 2022 rate hike.'),
    ('Model biaya', 'Spread 0.30 normal / 0.80 volatil; komisi per lot; slippage 0.05-0.20; swap malam untuk posisi swing; requote/rejection 1-3%. Contoh: 200 trade/tahun, 0.20 lot; biaya total ~9 per trade = ~1800/tahun \u2014 profit 10/trade tanpa biaya menjadi hanya 1.'),
    ('VectorBT & grid', 'Backtest dasar memakai sinyal entry/exit + fees + slippage; grid search lookback/ATR/RR \u2014 memilih parameter terbaik historis dari ribuan kombinasi = overfitting. Jangan pernah pilih yang terbaik tanpa Walk-Forward.'),
    ('Walk-forward', 'Standar emas: optimasi di IS (in-sample), uji di OOS (out-of-sample), lalu roll forward. Kriteria layak: OOS Sharpe > 0.5, >60% window positif, OOS max DD < 20%, OOS/IS Sharpe > 0.5, parameter tidak berubah drastis \u2014 IS 2.0 vs OOS 0.3 berarti overfit.'),
    ('Monte Carlo', 'Trade shuffling (acak urutan): P95 max DD > 30% = terlalu berisiko; prob profit < 80% = edge lemah. Bootstrap return utk simulasi setahun ke depan. Parameter perturbation \u00b110%: Sharpe tak boleh turun > 30%.'),
    ('Metrik', 'Target institusional: Sharpe > 1.0 (excellent > 2.0), Sortino > 1.5, Calmar > 1.0, Profit Factor > 1.5, Win Rate > 45% (dgn RR > 1.5), Max DD < 20%, Recovery Factor > 3, ulser rendah; total trades > 100 utk signifikansi statistik. Report QuantStats utk analisis visual.'),
    ('Regime & sesi', 'Per regime (trending up/down, ranging, vol tinggi/rendah): profit minimal 3 dari 5 regime = robust. Per sesi (asia/london/nY): bila London untung dan Asia rugi, pertimbangkan trading hanya di sesi menguntungkan.'),
    ('Anti-overfit & live', 'Ciri overfit: Sharpe IS >> OOS, parameter aneh (mis. lookback 7.3), banyak rule, performa berubah drastis utk perubahan \u00b15%, kurva terlalu mulus. Deflated Sharpe (koreksi multiple testing) > 0.95; CPCV utk validasi lebih dalam. Backtest wajib pakai risk engine yang SAMA dgn live. Transisi: paper 2-3 bulan (deviasi > 20% = masalah eksekusi) \u2192 small live 10-20% \u2192 full setelah konsisten; pantau TCA.'),
  ];

  static const _rowsDP = <(String, String)>[
    ('Filosofi', 'Tiga prinsip: reproducibility (bangun ulang environment identik dalam hitungan menit), observability (semua keputusan & error tercatat dan bisa di-query), graceful degradation (komponen gagal \u2192 pause trading, bukan panic-close). Institusi mengalokasikan 40-60% sumber daya engineering di fase ini.'),
    ('VPS 24/7', 'Windows Server di lokasi dekat broker (latency < 20ms; 5ms vs 50ms = slippage 0.05 vs 0.20). Spesifikasi: 4 vCPU, 8 GB. Matikan Windows Update otomatis (bisa restart tengah malam saat posisi buka), sleep/hibernate, screensaver; timezone UTC; auto-login; MT5 via Task Scheduler; Python 3.11 (bukan 3.12+ utk kompatibilitas MT5).'),
    ('Service layer', 'Jalankan MCP server & OpenCode runtime sbg Windows Service via NSSM: auto start, log stdout/stderr, rotation, restart-on-failure (delay 5-10 dtk). Wrapper loop PowerShell utk auto-restart saat crash.'),
    ('Logging', 'Level DEBUG/INFO/WARNING/ERROR/CRITICAL; structured JSON (bukan print), tiap peristiwa bertipe (signal, risk_check, order, fill, equity, error). Audit trail = hash-chain append-only (tamper-evident) + verifikasi integrity. Rotation: per 100 MB (10 backup) atau harian (30 hari).'),
    ('Monitoring', 'Prometheus/Grafana di VPS sekunder: metrik trading (equity, floating P/L, margin, DD, posisi per simbol), sistem (uptime, latency MT5/broker, CPU/RAM/disk, order & error per jam), eksekusi (spread, slippage, fill rate, waktu eksekusi). 5 panel: account overview, P/L & DD, aktivitas, kualitas eksekusi, system health.'),
    ('Alert', 'CRITICAL (crash, MT5 disconnect, kill switch, DD 20%) \u2192 Telegram + Email + SMS; HIGH (daily loss >2%, DD >10%) \u2192 Telegram + Email; MEDIUM (spread >1.00, slippage >0.30, 3+ penolakan risk) \u2192 Telegram; LOW (order rejected) \u2192 log saja.'),
    ('TCA', 'Kewajiban institusional: Implementation Shortfall (<0.20), VWAP slippage (<0.10), Arrival slippage (<0.15), spread cost, market impact, opportunity cost. Laporan harian & bulanan (avg, median, P95). Review berkala: slippage naik? eksekusi lambat? dampak besar? \u2192 ganti algo/broker/filter.'),
    ('Runbook & insiden', '10 runbook: MT5 disconnect, MCP crash, OpenCode crash, VPS unreachable, kill switch, daily loss, max drawdown, spread aneh, order rejected, broker outage. Severity: P1 (5 menit, telepon+SMS) \u2192 P2 (30 menit) \u2192 P3 (4 jam) \u2192 P4 (24 jam, log). Post-mortem wajib utk P1/P2: timeline, root cause, dampak, tindakan.'),
    ('Backup & DR', 'Backup: config (tiap perubahan), kode (git), state (tiap jam), log (harian, 90 hari), audit & TCA (permanen), MT5 profile (mingguan). Off-site S3 + cleanup 30 hari. DR: VPS mati \u2192 rebuild ~2 jam; data corrupt \u2192 ~30 menit; broker outage \u2192 pause & failover bila > 2 jam. Setelah 6 fase: multi-aset, multi-strategi, portfolio optimization, scale up, tim, regulasi.'),
  ];

  static const _rowsRM = <(String, String)>[
    ('Prinsip', 'Empat aturan: (1) jangan bangun semua sekaligus \u2014 tiap sprint = satu komponen berfungsi penuh & teruji; (2) paper trading dulu, live kemudian, jangan pernah skip; (3) 10 jam/minggu \u2248 9-12 bulan, itu normal \u2014 institusi butuh bertahun-tahun; (4) dokumentasikan saat membangun (yang dibangun, gagal, dipelajari).'),
    ('Proses > strategi', 'Pembeda institusional bukan strategi tapi proses & infrastruktur. Realitas: return 15-30%/tahun, Sharpe 1.5-2.5, Max DD 10-20%, win rate 45-55%, profit konsisten 1-2 tahun. Jika mencari 1000%/bulan, roadmap ini bukan untuk Anda.'),
    ('Sprint 0-1', 'Minggu 1 persiapan (8-12 jam): VPS Windows + Python 3.11 + MT5 demo + git repo + OpenCode + struktur folder (config/src/tests/logs/audit/backtest/docs). Minggu 2-3 koneksi MT5 (10-15 jam): metatrader-mcp-server, health_check.py, symbol_resolver, log pertama. Pitfall #1: lupa AutoTrading ON \u2014 80% kegagalan sprint ini.'),
    ('Sprint 2', 'Minggu 4-5 data & intelijen (12-18 jam): gold-mcp, macro_context (DXY, US10Y, VIX), seasonality, release_calendar, cache lokal utk hindari API berulang. Pitfall: overload informasi \u2014 mulai Gold-MCP saja, tambah sumber lain nanti.'),
    ('Sprint 3-4', 'Minggu 6-8 deteksi SMC + generator sinyal (35-50 jam): swing_detector, order_block, FVG, BOS/CHoCH, liquidity_sweep, session_filter, visualisasi chart; signal_generator (gabung SMC+makro+musiman) + validator, target 1-3 sinyal/hari. Pitfall: banyak false positive (tuning displacement_atr_mult & lookback); generator terlalu permisif/ketat.'),
    ('Sprint 5', 'Minggu 9-10 algoritma eksekusi (25-35 jam): spread_filter, VWAP/TWAP executor, order_router, slippage_monitor; uji order kecil 0.10 lot di demo. Pitfall: terlalu cepat = market impact; terlalu lambat = harga bergerak jauh \u2014 tuning interval child order.'),
    ('Sprint 6', 'Minggu 11-12 manajemen risiko (30-40 jam): position_sizing ATR, daily_limits, drawdown_guard, correlation_monitor, news_filter, kill_switch, recovery_protocol, risk_engine orkestrator. Pitfall: terlalu ketat = no trade; terlalu longgar = tidak berguna \u2014 mulai default, tuning setelah 100 trade.'),
    ('Sprint 7-8', 'Minggu 13-18 backtest & validasi (70-90 jam): data M15 2020-2025, cost_model realistis, custom engine + metrics, eksplorasi VectorBT; WFO minimal 4 window OOS (mean OOS Sharpe > 0.5, 60% window positif), Monte Carlo 10.000 sim (prob profit > 0.8, p95 DD < 30%), DSR, analisis per regime & sesi. Pitfall: skip WFO karena hasil IS sudah bagus.'),
    ('Sprint 9-13', 'Minggu 19+ deploy & live: Sprint 9-10 deploy 24/7 + TCA + runbook (45-65 jam); Sprint 11 paper 2 bulan (target Sharpe > 0.8, DD < 15%, trade > 50, deviasi vs backtest < 30%); Sprint 12 small live 10-20% modal (DD > 10% \u2192 kembali ke demo, slippage > 2x model \u2192 review broker); Sprint 13 full live naik 25%/bulan jika Sharpe rolling 3 bulan > 1.0. Total ~9-10 bulan (15-20 jam/minggu); biaya operasional 85-180 USD/bulan.'),
  ];

  static const _rowsSP0 = <(String, String)>[
    ('Tujuan', 'Fondasi lingkungan yang siap & teruji: VPS \u2192 MT5 \u2192 OpenCode \u2192 Git. Estimasi 8-12 jam (bisa 2 hari). Checklist awal: VPS Windows, akun demo MT5 (Exness/IC Markets/Pepperstone), kredensial login & server, akun Telegram + GitHub, budget 85-180 USD/bulan, waktu 10-20 jam/minggu selama 6-12 bulan.'),
    ('Pilih VPS', 'Windows Server 2019/2022 (MT5 native Windows); 2-4 vCPU; 4-8 GB RAM; 80-160 GB NVMe; lokasi dekat broker utk latency < 20ms; SLA 99.9%+. Pemula: Vultr/Contabo (40-80 USD/bln); saat profitable upgrade ke ForexVPS (50-100 USD/bln) atau Beeks (colocation, 200+ USD). Simpan kredensial di password manager (Bitwarden/1Password).'),
    ('Setup Windows', 'RDP pertama; Set-TimeZone UTC; update sekali pake PSWindowsUpdate. KRUSIAL: matikan Windows Update otomatis (wuauserv Manual, WaaSMedicSvc Start=4, disable scheduled tasks UpdateOrchestrator/WindowsUpdate) \u2014 bisa restart VPS tengah malam saat posisi buka. Matikan hibernate/sleep/screensaver (powercfg -h off; standby & monitor timeout 0). Auto-login via netplwiz atau Sysinternals AutoLogon. Defender exclusion folder C:/trading + folder MT5; firewall buka port 9090 & 8000 khusus 127.0.0.1.'),
    ('Instal software', 'Python 3.11 (PENTING: bukan 3.12+ \u2014 library MetaTrader5 belum kompatibel), 3.11.9 amd64 silent + PrependPath; Visual C++ Redistributable; Git 2.44; Chocolatey (notepadplusplus, 7zip, curl, nssm, vscode). MT5 di-download dari WEBSITE BROKER (bukan MetaQuotes) supaya terhubung ke server broker; login demo; aktifkan AutoTrading (Tools\u2192Options\u2192Expert Advisors\u2192Allow algorithmic trading + tombol toolbar hijau); cari simbol XAUUSD/GOLD di Market Watch, catat nama asli di docs/broker_info.md. AutoTrading OFF = 80% kegagalan Sprint 0.'),
    ('Struktur & git', 'Folder C:/trading lengkap: config; src/{connection,strategy,execution,risk,data,utils,monitoring}; tests/{unit,integration}; logs/{signals,orders,errors}; audit; backtest/{data,results,reports}; docs; incidents; runbook; scripts. git init + .gitignore (JANGAN commit .env, *.key, *credentials*, config/secrets.yaml; exclude logs, backtest/data, daily_state.json, kill_switch.json); requirements.txt (MetaTrader5 5.0.45, pandas, numpy, scipy, scikit-learn, vectorbt, quantstats, prometheus-client, python-telegram-bot, tenacity, dll.); python -m venv venv + pip install.'),
    ('Config', 'config/settings.yaml: system (env demo, timezone UTC); mt5 symbol + alternatif (XAUUSDm, GOLD, 44 varian) + timeframe M15 + magic; risk (1% per trade, daily loss 3%, daily profit 6%, 10 trade/hari, DD 4 level 5/10/15/20%); execution (algo vwap, horizon 60 menit, spread normal 0.30 / volatile 0.60, slippage 20 pts); strategy SMC (swing_lookback 5, displacement 1.5 ATR, FVG 0.3 ATR, sesi London/NY); logging json. config/.env.example (MT5 login/pass/server/path, MCP host/port, TELEGRAM, FXMACRODATA API key, S3). config/opencode.json (mcp remote http://127.0.0.1:9090/sse).'),
    ('Health check', 'src/connection/health_check.py: mt5.initialize(path,login,password,server) \u2192 account_info (balance, equity, leverage, trade_mode DEMO/REAL) \u2192 resolve_xauusd_symbol (coba daftar alternatif, fallback scan semua simbol berisi XAU/GOLD) \u2192 symbol_info_tick (bid, ask, spread+points, digits, contract size, min/max lot, lot step). Output: ALL CHECKS PASSED. Jalankan (setelah aktivasi venv): python -m src.connection.health_check.'),
    ('OpenCode & git remote', 'Install opencode di VPS (npm via choco nodejs) atau di lokal (irm https://opencode.ai/install.ps1) + tunnel SSH ke MCP. Config: opencode.json (mcp remote) + docs/agent_instructions.md (risk first; jangan market order > 0.10 lot \u2014 wajib VWAP/TWAP; cek spread dulu; log tiap keputusan; jangan simpan password di log; jangan commit kredensial). Test via natural language: Health check, Show account info, Show XAUUSD price. GitHub repo PRIVATE, push pakai Personal Access Token; pre-commit hook blokir .env/credentials.'),
    ('Backup & verifikasi', 'scripts/backup.ps1 harian 03:00 via Scheduled Task (SYSTEM service account), Compress-Archive isi folder C:/trading, retensi hapus > 30 hari. Docs: setup.md + broker_info.md (server, simbol, spread per sesi, swap long -8 / short -5 USD per lot, model eksekusi). Troubleshooting: MT5 initialize failed (path terminal / terminal belum jalan); import MetaTrader5 gagal (wajib Python 3.11); vectorbt (upgrade numba + pip install --no-deps); simbol tak ketemu (cek Market Watch); MCP tak connect (curl http://127.0.0.1:9090/health); latency tinggi (pindah lokasi VPS/broker). Total ~13 jam. Checklist 5 pertanyaan: health check, OpenCode bisa jalankan, .env aman, backup terjadwal, dokumen lengkap \u2192 semua Ya = Sprint 0 selesai.'),
  ];

  static const _rowsSP1 = <(String, String)>[
    ('Tujuan', 'Fase 1: OpenCode bisa baca data MT5 & kirim order via MCP. Estimasi 10-15 jam (2 minggu). Deliverables: metatrader-mcp-server terinstal & berjalan, config OpenCode terhubung, health_check.py + symbol_resolver.py, log pertama di logs/. Milestone: tanya "Berapa harga XAUUSD sekarang?" dapat jawaban real-time.'),
    ('Sebelum mulai', 'Pastikan dari Sprint 0: MT5 login demo + AutoTrading ON (80% kegagalan sprint ini karena tombol AutoTrading OFF), Python 3.11 + venv aktif, config/.env berisi MT5_LOGIN/PASSWORD/SERVER/PATH, port MCP 9090 dibuka (localhost only), NSSM terinstal. Pilihan server: metatrader-mcp-server (self-host) \u2014 atau SYNX (managed) utk pemula yang kurang nyaman self-host.'),
    ('Arsitektur', 'MCP (Model Context Protocol) menjembatani OpenCode \u2192 tool MCP \u2192 MT5 di VPS yang sama. Rantai: MT5 terminal (AutoTrading ON, EA OFF, XAUUSD di Market Watch) \u2192 MCP server (Windows Service, auto-restart, HTTP 127.0.0.1:9090) \u2192 OpenCode runtime (MCP client + strategy engine + risk engine) via SSE/HTTP. Prinsip kunci: MCP WAJIB service, bukan proses manual \u2014 kalau VPS restart, service hidup tanpa intervensi.'),
    ('Pilih MCP server', 'metatrader-mcp-server (ariadng): paling populer, 68+ tools (akun, market data, order) \u2014 rekomendasi mulai. SYNX-MT5-MCP: 68+ tools + fitur institusional (capability profile read_only \u2192 analyst \u2192 executor \u2192 full, pre-flight risk validation, drawdown circuit breaker, tamper-evident audit logging, credential vault OS keyring bukan env var), kompatibel OpenCode Desktop & CLI. Rekomendasi: mulai metatrader-mcp-server, migrasi SYNX saat sistem stabil & butuh fitur institusional.'),
    ('Windows Service', 'Install NSSM (choco install -y nssm) lalu bungkus proses sbg service asli. Wrapper run_mcp.ps1: baca config/.env \u2192 set environment \u2192 aktifkan venv \u2192 jalankan python -m metatrader_mcp_server --login/--password/--server/--host 127.0.0.1/--port 9090 \u2194 log harian. nssm install MT5MCP (powershell -File wrapper), AppDirectory C:/trading, AppStdout/AppStderr \u2192 logs/mcp dgn AppRotateBytes 10 MB, AppExit Default Restart + AppRestartDelay 5000 (auto-restart saat crash = graceful). Verifikasi: nssm status \u2192 SERVICE_RUNNING; netstat port 9090; curl /health \u2192 OK.'),
    ('symbol_resolver', 'JANGAN hardcode XAUUSD. Dari 230+ broker ada 44 varian nama emas: mayoritas (68%) XAUUSD; Exness XAUUSDm / XAUUSDc; varian lain XAUUSD.m, XAUUSD.s, XAUUSDp, XAUUSD.pro, GOLD, GOLD_USD, XAU/USD. Strategi resolver: (1) coba XAUUSD_ALTERNATIVES via symbol_info; (2) fallback scan symbols_get() dgn nama mengandung XAU/GOLD; (3) urutkan kandidat \u2014 prioritas nama bnr XAUUSD, lalu nama terpendek. validate_symbol: symbol_info + symbol_select bila belum visible di Market Watch. get_symbol_specs: digits, point, spread, contract size, min/max lot + step, tick value/size, margin initial, swap long/short, currency. Hasil dicatat ke docs/broker_info.md + config/settings.yaml \u2014 jadi hardcode hanya sekali.'),
    ('Katalog tools', 'Account: get_account_info, get_account_summary, get_positions, get_orders, get_history. Market data: get_symbols, get_symbol_info, get_symbol_price, get_ohlcv, get_ticks. Trading: place_order, modify_order, cancel_order, close_position, close_all_positions. Contoh query: "Show my account information", "Get XAUUSD OHLCV last 50 candles M15", "Show all open positions". Semua melewati MCP client \u2014 agent tidak pernah akses MT5 langsung.'),
    ('MCP logger', 'src/connection/mcp_logger.py: catat SETIAP MCP call ke JSONL (logs/mcp/mcp_YYYYMMDD.jsonl) \u2014 timestamp, session_id, tool, params, result_summary, success. Ringkas hasil besar: array/dict jadi "<list len=N>", string dipotong 100 karakter (jangan log data mentah yg besar). Error dipisah ke mcp_errors_*.jsonl. Integrasikan di health_check & tiap handler; ini bahan debug, audit, dan input TCA nanti.'),
    ('Full health check', 'full_health_check.py.end2end: connect \u2192 account (balance, equity, margin, free margin, floating P/L, leverage, DEMO/REAL) \u2192 symbol resolve + validate + print specs \u2192 tick bid/ask + spread \u2192 positions (ticket, lot, harga, SL/TP, P/L, swap) \u2192 pending orders \u2192 "SPRINT 1 HEALTH CHECK PASSED". Setiap langkah dilepas lewat MCP logger. Jalankan: python -m src.connection.full_health_check.'),
    ('Test & verifikasi', 'Suite minimal: terminal_info() is not None; account_info() balance > 0; symbol_info_tick(bid) > 0. Test order KECIL di demo (0.01 lot) lalu close \u2014 verifikasi fill & log. Verifikasi 8 query via OpenCode (health check, account, price, positions, orders, history 24 jam, OHLCV 50 candle M15, symbol specs): semua balas < 5 detik dgn hasil masuk akal; get_positions/get_orders boleh kosong. Pastikan jawaban datang dari MCP (data real), bukan data statis.'),
    ('Monitoring service', 'scripts/monitor_mcp.ps1 dijadwalkan tiap 5 menit (Task Scheduler, SYSTEM): curl /health timeout 5 dtk, 3x retry jeda 3 dtk; gagal \u2192 Restart-Service MT5MCP, tunggu 10 dtk, cek ulang; masih gagal \u2192 tulis "manual intervention required" (alert dikirim di Fase 6). Watchdog eksternal jangan andalkan auto-restart NSSM saja.'),
    ('Troubleshooting', 'Service tidak start: baca mcp_stderr.log, cek proses terminal64 (MT5), start manual lalu nssm restart. OpenCode disconnected: curl /sse, netstat 9090, cek firewall, restart OpenCode. initialize() failed: MT5 harus BERJALAN (bukan terinstal), path/login/server benar, AutoTrading aktif. Symbol not found: cek Market Watch, tambah ke XAUUSD_ALTERNATIVES. Crash setelah jam: WorkingSet python > 500 MB = indikasi memory leak \u2192 auto-restart berkala. Order ditolak "trading not enabled": Tools\u2192Options\u2192Expert Advisors\u2192Allow algorithmic trading + tombol hijau.'),
    ('Checklist', '4 bagian: (1) instalasi \u2014 server di venv, wrapper, NSSM, service jalan, auto-restart, log rotation, config OpenCode, agent instructions; (2) fungsionalitas \u2014 health check via Python & OpenCode, semua tools balas, resolver 44 varian; (3) monitoring \u2014 JSONL per call, watchdog 5 menit; (4) dokumentasi \u2014 broker_info.md, setup.md, screenshot query. Estimasi total ~14 jam (2 minggu @ 7 jam/minggu). Keluar sprint saat semua tools terverifikasi & service stabil 24/7.'),
  ];

  static const _rowsSP2 = <(String, String)>[
    ('Tujuan', 'Fase 2: sistem tidak hanya bereaksi harga, tapi memahaminya. Estimasi 12-18 jam (2-3 minggu @ 5-7 jam/minggu), breakdown total ~15 jam. Deliverables: gold-mcp, xaudaily, fxmacrodata, quantgist terhubung; macro_cache.py; macro_context/seasonality/release_calendar; 4 filter (makro, musiman, event risk); data_logger; mcp_health_check. Milestone: tanya "Konteks makro emas hari ini?" dapat DXY + US10Y + VIX + bias musiman + jadwal rilis, dan sinyal SMC otomatis tertolak atau dikecilkan bila makro berlawanan.'),
    ('4 pilar makro', 'Emas tidak bergerak di ruang hampa \u2014 4 pilar wajib dipantau: DXY (korelasi -0.63, dolar turun \u2192 emas naik), real interest rates US10Y/TIPS (-0.82, hubungan terbalik TERKUAT), VIX & SPX (korelasi positif, VIX naik \u2192 emas safe haven), dan likuiditas global (neraca bank sentral, M2 positif). Tanpa-fourth pilar ini, sistem rentan false signal karena hanya melihat harga tanpa penyebabnya.'),
    ('Gold-MCP', 'Rekomendasi utama (ThaiTrevor). Free tier sudah fungsional: 13 tools + 8 tool MT5 BYOK. Tools kunci: get_gold_price (harga terakhir + perubahan 24 jam), get_gold_ohlcv (1m s/d 1mo), get_macro_context (DXY, US10Y/02Y, SPX, VIX, BTC, silver, oil), get_gold_correlations (matriks korelasi), get_gold_seasonality (return harian/bulanan), gold_market_snapshot (agregator satu panggilan). Tier: Free, Pro (9-19 USD/bln), Premium (29-49), Ultra (99-149). v4.1: realtime PAXG via Binance WebSocket tanpa API key (paxg_worker_status, get_paxg_tick, get_paxg_ohlcv_realtime; PAXG melacak XAU/USD dalam 0.1-0.3%). Adapter MT5 BYOK opsional di Windows: pip install gold-mcp[mt5] \u2192 mt5_attach, mt5_find_symbol (resolusi simbol broker), mt5_get_tick, mt5_account_info; kredensial tidak melintasi server. Instalasi: pip install gold-mcp; verifikasi python -c "import gold_mcp; print(gold_mcp.__version__)". Aturan anti-overload: mulai dari Gold-MCP SAJA, tambah sumber lain hanya saat strategi terbukti butuh.'),
    ('xaudaily-gold-data', 'Alternatif zero-dependency dari xaudaily.com: satu file Python, standard library saja, tanpa pip. Data: COMEX gold & Shanghai Au99.99 (tick live ~30 menit), CPI/core PCE/nonfarm payrolls/PPI, DXY, Treasury 10Y & 30Y, VIX, SPDR gold ETF holdings, Fed funds rate + Polymarket odds untuk FOMC berikutnya, IMF central-bank gold buying, Brent/WTI, US debt, dan rule-based gold driver score. Setiap field membawa source + asOf/date sendiri sehingga sitasi bisa diverifikasi; jika upstream gagal, field ditandai stale: true alih-alih menyajikan angka lama secara diam-diam. Update 2x sehari (06:30 & 22:40 JST) \u2014 DAILY READINGS, bukan real-time feed. Instalasi: git clone .../xaudaily-gold-data.git lalu arahkan command ke mcp_server.py.'),
    ('FXMacroData', 'Untuk data makro historis lengkap + posisi COT. Tanpa API key: data USD 90 hari terakhir; dengan key: data non-USD dan histori penuh. Tools: release_calendar (jadwal rilis mendatang), indicator_query (time series CPI, NFP, dll), cot_data (CFTC Commitment of Traders positioning), commodities (gold/silver/platinum), forex (spot rate + indikator teknikal opsional), market_sessions (Sydney/Tokyo/London/New York). Instalasi: pip install uv lalu uvx mcp-server-fxmacrodata; opsional set env FXMACRODATA_API_KEY untuk data lengkap.'),
    ('QuantGist', 'Fokus pada event risk management, 11 tools. Tools kunci: get_upcoming_events (event N jam ke depan + filter by impact), check_safe_to_trade (apakah aman trading simbol sekarang), get_economic_calendar (kalender ekonomi lengkap), get_markets_overview (quotes end-of-day untuk indeks & instrumen), plus pengecekan keamanan trading dan earnings. Instalasi: pip install quantgist-mcp; API key gratis 100 calls/hari dari quantgist.com, simpan di env QUANTGIST_API_KEY.'),
    ('Arsitektur data', 'Kombinasi 5 sumber di bawah OpenCode AI Agent: MT5 MCP (Fase 1) + Gold-MCP + xaudaily + FXMacroData + QuantGist. Pembagian peran dan frekuensi: MT5 = eksekusi order, tick data, account info (real-time); Gold-MCP = konteks makro, korelasi, seasonality, snapshot (on-demand); xaudaily = daily brief, CPI/NFP, FOMC odds (2x sehari); FXMacroData = COT positioning, release calendar (mingguan/harian); QuantGist = event risk, kalender ekonomi (harian). Jangan tumpuk semua sekaligus \u2014 aktifkan bertahap sesuai kebutuhan strategi.'),
    ('Konfigurasi OpenCode', 'Edit %USERPROFILE%/.config/opencode/opencode.json. type "local" untuk MCP yang dijalankan sebagai subprocess (stdio, wajib ada command), type "remote" untuk yang diakses via HTTP/SSE (wajib ada url). Lima entry: metatrader (remote, http://127.0.0.1:9090/sse), gold-mcp (python -m gold_mcp.server), xaudaily (python3 C:/trading/xaudaily-gold-data/mcp_server.py + env XAUDaily_READINGS_URL & XAUDaily_BRIEF_URL), fxmacrodata (uvx mcp-server-fxmacrodata + env FXMACRODATA_API_KEY), quantgist (command quantgist-mcp + env QUANTGIST_API_KEY). Semua enabled true, timeout 30000. Kunci API di env/.env, jangan di dalam kode.'),
    ('Test query', 'Restart OpenCode lalu /opencode mcp list \u2192 metatrader, gold-mcp, xaudaily, fxmacrodata, quantgist semuanya connected. Lalu 7 query wajib: (1) macro context untuk emas, (2) seasonality bulan ini, (3) korelasi emas vs DXY/US10Y/VIX, (4) daily brief hari ini, (5) release calendar USD mendatang, (6) "is it safe to trade XAUUSD right now?", (7) COT CFTC untuk emas. Semua harus mengembalikan hasil yang masuk akal; query yang gagal dicatat sebagai bahan troubleshooting, bukan diabaikan.'),
    ('Cache lokal', 'src/data/macro_cache.py kelas MacroCache: cache_dir data/cache, cache key md5(source:query), file <hash>.json berisi source, query, cached_at (ISO), data. get() mengembalikan None bila miss atau expired, set() menulis entry, clear_expired() menghapus file yang lewat TTL. TTL per jenis data: harga XAUUSD 1 menit (berubah cepat); DXY/US10Y/VIX 5 menit; korelasi 1 jam; musiman 24 jam; release calendar 6 jam; COT 7 hari (dirilis mingguan). Cache juga menyimpan riwayat untuk backtest nanti. Bersihkan manual: python -c "from src.data.macro_cache import MacroCache; MacroCache().clear_expired()".'),
    ('Filter makro', 'macro_filter_buy(): tolak BUY bila DXY_change_pct > 0.5 (rally dolar), US10Y_change > 0.05 (yield melonjak), atau VIX < 12 (risk-on ekstrem, safe haven lemah). macro_filter_sell(): tolak SELL bila DXY_change_pct < -0.5 atau US10Y_change < -0.05. Dua-duanya return (allowed, reason) sehingga alasan penolakan ikut masuk ke log sinyal dan bisa ditinjau di TCA nanti.'),
    ('Filter musiman', 'seasonality_filter(seasonality, direction): BUY dengan month_bias bearish \u2192 skip bila current_month_winrate < 0.35, selain itu kurangi size 50%; SELL dengan month_bias bullish \u2192 skip bila winrate > 0.65, selain itu kurangi size 50%; bias netral \u2192 lolos penuh. Signal generator menurunkan confidence 0.2 saat musiman berlawanan. Dipakai sebagai filter, bukan sinyal tunggal.'),
    ('Event risk filter', 'event_risk_filter(release_calendar, direction): blokir hanya event impact high, window Forbidden 15 menit sebelum sampai 15 menit setelah waktu rilis (dibandingkan now dalam UTC). Event impact low/medium tetap lolos. Tujuannya mencegah entry di tengah lonjakan volatilitas, bukan memprediksi arah harga setelah rilis.'),
    ('Integrasi signal generator', 'generate_signal(df, macro_context, seasonality, release_calendar) berjalan 6 langkah: (1) SMC \u2014 deteksi structure, order block, FVG, liquidity sweep; tanpa sweep atau OB \u2192 HOLD + alasan; (2) arah hanya jika bullish_sweep + bias bullish atau bearish_sweep + bias bearish, selain itu HOLD "sweep tidak konfirmasi struktur"; (3) filter makro; (4) filter musiman; (5) event risk filter; (6) hitung level \u2014 entry OB-mid, SL di luar OB plus 20% tinggi OB, TP = RR 1:3. Confidence dasar 0.7, +0.1 bila FVG ada. Output dict: action, confidence, reason[], entry, stop_loss, take_profit, macro_context, seasonality.'),
    ('Logging & health check', 'src/data/data_logger.py kelas DataLogger: log_dir logs/data, session_id YYYYMMDD_HHMMSS; log_fetch(source, query, result_summary, latency_ms) dan log_error(source, query, error) menulis JSONL per hari (data_YYYYMMDD.jsonl, data_errors_YYYYMMDD.jsonl). src/data/mcp_health_check.py kelas MCPHealthCheck: satu probe per server \u2014 gold-mcp get_gold_price, xaudaily get_gold_readings, fxmacrodata ping, quantgist get_upcoming_events hours 24 \u2014 lalu run_all() merangkum "ALL 4 MCP servers OK" atau "N/4 OK" beserta latency. Jalankan: python -m src.data.mcp_health_check.'),
    ('Skenario end-to-end', 'Sinyal BUY dari SMC di sesi London (liquidity sweep + displacement bullish): get_macro_context \u2192 DXY -0.45% (bullish emas), US10Y 4.15% turun 0.03 (bullish emas), VIX 18.5 naik 5.2% (permintaan safe haven) \u2192 lolos; get_gold_seasonality \u2192 bulan ini historisnya bullish \u2192 lolos; release_calendar \u2192 tidak ada CPI/NFP/FOMC dalam 4 jam \u2192 lolos; semua filter hijau \u2192 BUY dieksekusi size penuh. Kalau salah satu filter gagal \u2192 sinyal dilewati, atau size dikurangi 50%.'),
    ('Troubleshooting', 'Gold-MCP tidak muncul di /opencode mcp list \u2192 cek import gold_mcp, coba python -m gold_mcp.server manual, lalu reinstall. xaudaily FileNotFoundError \u2192 Test-Path C:/trading/xaudaily-gold-data/mcp_server.py, clone ulang bila kosong. FXMacroData timeout 30 detik \u2192 test uvx mcp-server-fxmacrodata manual, cek koneksi internet, isi FXMACRODATA_API_KEY. Data tidak konsisten antar sumber (DXY dari Gold-MCP beda dengan xaudaily) \u2192 itu NORMAL; pilih satu sumber utama per indikator, sumber lain hanya cross-check, catat di docs/data_sources.md. Cache terlalu basi \u2192 MacroCache().clear_expired().'),
    ('Checklist, dokumentasi & estimasi', '5 bagian \u2014 (1) instalasi: gold-mcp, xaudaily, fxmacrodata, quantgist terhubung + cache lokal; (2) fungsionalitas: get_macro_context, get_gold_seasonality, get_gold_correlations, get_gold_readings, release_calendar, cot_data, check_safe_to_trade; (3) integrasi: 4 filter masuk signal_generator, sinyal ditolak bila filter gagal, size dikecilkan bila musiman kontra; (4) logging: setiap fetch + latency + error tercatat, health check 4 server; (5) dokumentasi: docs/data_sources.md, docs/mcp_config.md, screenshot query. Estimasi ~15 jam total (4x30 menit instalasi, 1 jam config, 2 jam cache, 2 jam filter, 2 jam integrasi, 1 jam logger, 1 jam health check, 2 jam test, 2 jam troubleshooting, 1 jam dokumentasi). Keluar sprint saat semua query realistis dan filter terbukti menolak sinyal buruk.'),
  ];

  static const _rowsSP3 = <(String, String)>[
    ('Tujuan', 'Fase 3: sistem berubah dari "robot yang bisa kirim order" menjadi agen trading berstrategi. Dibagi dua: OTAK (logika strategi penghasil sinyal berkualitas) dan TANGAN (algoritma eksekusi yang mengubah sinyal jadi order tanpa merusak harga). Total sprint 30-40 jam (4-5 minggu @ 7-8 jam/minggu), dipecah 3 sub-sprint berurutan: 3a deteksi SMC (Swing, OB, FVG, BOS/CHoCH, Sweep) ~31 jam, 3b generator sinyal + filter sesi 15-20 jam, 3c algoritma eksekusi VWAP/TWAP + filter + router. Target akhir: deteksi setup SMC, validasi dengan data makro Sprint 2, eksekusi via VWAP dengan filter spread & slippage, terintegrasi penuh dengan risk engine.'),
    ('Filosofi SMC (4 konsep)', 'SMC bukan menebak arah, tapi membaca jejak likuiditas dan ketidakseimbangan order. (a) ORDER BLOCK: zona harga tempat institusi placing order besar sebelum impuls; OB bullish = candle bearish terakhir sebelum kenaikan impulsif, OB bearish = kebalikan. (b) LIQUIDITY SWEEP: harga menyapu stop loss retail di atas swing high / bawah swing low lalu berbalik \u2014 jebakan klasik untuk mengumpulkan likuiditas. (c) FAIR VALUE GAP / IMBALANCE: ketidakseimbangan saat displacement kuat; 3 candle berurutan dengan gap antara high candle 1 dan low candle 3. (d) BOS & CHoCH: BOS = tembus swing high/low SEARAH tren (konfirmasi kelanjutan), CHoCH = tembus berlawanan tren (indikasi reversal).'),
    ('Struktur modul', 'Tujuh file di src/strategy/: swing_detector.py (swing high/low), order_block.py (OB + calculate_atr), fvg.py (Fair Value Gap), bos_choch.py (BOS/CHoCH + bias), liquidity_sweep.py (sweep), session_filter.py (klasifikasi sesi), smc_pipeline.py (orkestrator SMCAnalyzer). Semua modul pure function berbasis pandas DataFrame OHLCV \u2014 input dataframe, output list/dict, tanpa akses MT5 di dalam modul. Ini yang membuat unit test inexpensive dan backtest konsisten.'),
    ('Siklus 3 sesi XAUUSD', 'WIB: Asia 07:00-15:00 (akumulasi, range sempit), London 15:00-23:00 (manipulasi, liquidity sweep), New York 20:00-04:00 (distribusi, tren utama). Pola setup terbaik: London menyapu likuiditas Asia, lalu New York melanjutkan tren. Karena London dan NY overlap 20:00-23:00, window itu punya karakter hybrid \u2014 likuiditas tinggi plus news US, sehingga spread melebar dan perlu filter ketat.'),
    ('Swing detector', 'src/strategy/swing_detector.py: detect_swing_points(df, lookback=5, min_bars_between=3). Guard: panjang data < lookback*2+1 \u2192 return df tanpa swing. Swing high bila high saat ini == max high dalam window lookback kiri + kanan; swing low bila low == min low. min_bars_between mencegah swing bertumpuk. Output kolom tambahan swing_high, swing_low, swing_high_price, swing_low_price. Helper get_last_swing_high(df, n) / get_last_swing_low(df, n) mengembalikan dict time, price, index atau None bila kurang dari n. Tuning: makin kecil lookback = makin banyak swing (noise); makin besar = makin sedikit (terlambat). Selalu visualkan titik swing sebelum lanjut.'),
    ('Order block detector', 'src/strategy/order_block.py: calculate_atr(df, period=14) memakai true range max(high-low, |high-close_prev|, |low-close_prev|) lalu rolling mean. detect_order_blocks(df, displacement_atr_mult=1.5, atr_period=14, max_ob_age_bars=100): candle i jadi OB bila body candle i+1 > ATR*1.5 (displacement) \u2014 bullish bila candle i bearish lalu candle i+1 bullish, bearish kebalikan. Dict per OB: type, time, index, top, bottom, mid, body_high, body_low, displacement_body, atr_at_formation, age_bars, tested, mitigated. Scan ulang bar setelah OB: harga masuk zona \u2192 tested=True; close menembus bottom (bullish) atau top (bearish) \u2192 mitigated=True dan loop berhenti. Return HANYA OB yang belum mitigated. get_nearest_ob(df, current_price, direction) mengurutkan kandidat berdasarkan jarak abs(mid - current_price) lalu ambil yang terdekat.'),
    ('Fair value gap detector', 'src/strategy/fvg.py: detect_fvg(df, min_gap_atr=0.3, atr_period=14, max_fvg_age_bars=200). Bullish FVG bila low candle i - high candle i-2 > ATR*0.3 (gap antar candle 1 dan 3, time dicatat pada candle tengah i-1); bearish kebalikan. Dict: type, time, index, top, bottom, size, size_atr, age_bars, filled, fill_pct. Scan ulang melacak fill bertahap: low <= bottom \u2192 filled True, fill_pct 1.0; low <= top (belum penuh) \u2192 fill_pct = (top - low)/size. Helper get_unfilled_fvg(df, direction) hanya mengembalikan FVG unfilled searah. FVG ter-fill adalah peluang entry, bukan sinyal jual otomatis.'),
    ('BOS/CHoCH detector', 'src/strategy/bos_choch.py: detect_structure(df, lookback=5) memanggil detect_swing_points lalu butuh minimal 2 swing high dan 2 swing low, jika tidak \u2192 bias neutral tanpa event. Bias dari tiga swing terakhir: HH + HL = bullish, LH + LL = bearish, selain itu neutral. Event BOS bila harga break searah tren (swing high pecah ketika swing high sebelumnya lebih rendah untuk versi bearish, dan sebaliknya), CHoCH bila melawan; setiap event menyimpan type, direction, level, break_time, swing_time, lalu diurutkan berdasarkan break_time. Butuh swing high DAN swing low \u2014 bila salah satu kurang, bias tidak bisa ditentukan dan setup tertahan.'),
    ('Liquidity sweep detector', 'src/strategy/liquidity_sweep.py: detect_liquidity_sweep(df, lookback=20, max_bars_after_sweep=5, require_close_back=True). Bearish sweep bila high candle > swing high TAPI close kembali di bawah level itu (require_close_back menolak breakout valid); bullish sweep kebalikan (low < swing low lalu close kembali di atas). Scan hanya max_bars_after_sweep bar setelah swing. Dict: type, time, index, swept_level, sweep_high atau sweep_low, close, penetration (kedalaman penetrating), rejection (jarak close dari ekstrem), swing_time. Helper get_recent_sweep(df, max_age_bars=10) membuang sweep yang sudah terlalu tua. Validasi close-back inilah pembeda sweep nyata vs breakout sah \u2014 tanpa itu sistem akan salah entry saat tren benar-benar berganti.'),
    ('Session filter', 'src/strategy/session_filter.py: SESSIONS dalam UTC \u2014 asia 00:00-07:00 (accumulation, tidak tradeable), london 07:00-12:00 (manipulation, tradeable), newyork 12:00-21:00 (distribution, tradeable), off_hours 21:00-00:00 (low_liquidity, tidak tradeable). get_session() melokalisasi timestamp naive ke UTC lalu mencocokkan; sesi off_hours menangani wrap tengah malam. is_tradeable_session(timestamp, allowed=("london","newyork")). get_session_quality() mengembalikan quality_score: newyork 1.0, london 0.9, asia 0.3, off_hours 0.1. is_killzone(): London open 07:00-10:00 UTC atau NY open 12:00-15:00 UTC \u2014 window terbaik untuk entry, bukan hanya penanda sesi.'),
    ('SMC pipeline', 'src/strategy/smc_pipeline.py kelas SMCAnalyzer(config): default swing_lookback 5, displacement_atr_mult 1.5, fvg_min_gap_atr 0.3, atr_period 14, sweep_max_age_bars 10, allowed_sessions (london, newyork). analyze(df) guard len < 50 \u2192 valid False "Insufficient data", lalu 6 langkah berurutan: (1) detect_swing_points, (2) detect_order_blocks, (3) detect_fvg, (4) detect_structure \u2192 bias, (5) get_recent_sweep, (6) _detect_setup. Output menyertakan timestamp, current_price, session, is_killzone, is_tradeable_session, swings, order_blocks, fvgs, structure, sweep, bias, setup.'),
    ('Deteksi setup & confidence', '_detect_setup() mengembalikan None bila: sesi tidak tradeable, tidak ada sweep, atau bias struktur tidak searah sweep (bullish_sweep butuh bias bullish). Setelah itu ambil OB searah yang terdekat dari current_price. Confidence mulai 0.5, lalu +0.15 bila killzone, +0.10 bila ada FVG unfilled searah, +0.10 bila rejection > penetration (sweep benar-benar ditolak, bukan sekadar menembus tipis), +0.10 bila last_event adalah BOS; dibatasi min(confidence, 1.0). Level: entry OB-mid, SL di luar OB plus 20% tinggi OB, TP = RR 3.0. Setup hanya muncul bila sweep + OB + bias searah + sesi tradeable \u2014 empat syarat, bukan satu.'),
    ('Skill OpenCode & logging', 'src/strategy/smc_skill.py: mt5.initialize() \u2192 find_xauusd_symbol() dari Sprint 1 \u2192 fetch_data(symbol, timeframe, n_bars=500) memakai mt5.copy_rates_from_pos lalu kolom tick_volume di-rename jadi volume \u2192 SMCAnalyzer().analyze() \u2192 print JSON (default) atau teks. Guard: symbol tidak ditemukan, data None, atau len < 50 \u2192 keluar dengan pesan jelas. mt5.shutdown() di blok finally. Flag --timeframe (M5/M15/M30/H1/H4, default M15) dan --output (json/text). Di OpenCode: "Run SMC analysis on XAUUSD M15" \u2192 python -m src.strategy.smc_skill --timeframe M15 --output json. Logging: SMCAnalyzer memakai MCPLogger(log_dir="logs/smc") lalu log_call("smc_analyze", {bars, last_price}, result) di setiap analyze().'),
    ('Unit test', 'tests/unit/test_smc.py: fixture sample_data synthetic \u2014 200 bar M15, base_price 2345.0, random walk np.random.seed(42) supaya hasil reproducible. test_smc_analyzer_runs: valid True dan kunci bias, order_blocks, fvgs, structure ada. test_order_block_detection: type hanya bullish/bearish dan semua top > bottom. test_fvg_detection: semua top > bottom. test_session_filter: 08:00 UTC = london, 14:00 UTC = newyork, 03:00 UTC = asia; killzone true di 08:00 dan 13:00 UTC, false di 04:00. Jalankan pytest tests/unit/test_smc.py -v. Tambah test regresi setiap ada perubahan parameter supaya perilaku lama tidak rusak diam-diam.'),
    ('Data & visualisasi', 'Uji pada data historis yang sama dgn sumber backtest (M15/H1). Visualisasi itu wajib, bukan opsional: gambarkan OB (kotak), FVG (isi celah), sweep (panah), BOS/CHoCH (label) di chart \u2014 evaluasi pakai mata dulu, angka kemudian. Sistem yang "terlihat benar" tapi gagal angka = parameter belum konsisten.'),
    ('Pitfall & tuning', 'Pitfall #1: terlalu banyak false positive. Pitfall #2: swept tanpa close-back ikut terhitung sebagai breakout sah. Pitfall #3: OB lama yang sudah mitigated masih dipakai sebagai entry. Tuning bertahap: displacement_atr_mult (kekuatan impuls), lookback (lebar swing), fvg_min_gap_atr, require_close_back, sweep_max_age_bars. Aturan: ubah SATU parameter, amati dampak di chart + test, lalu catat di docs apa yang berubah dan kenapa \u2014 bukan trial-and-error tanpa jejak.'),
    ('Checklist', '13 poin: swing_detector mendeteksi swing high/low dengan benar; order_block mendeteksi OB bullish dan bearish; fvg mendeteksi FVG bullish dan bearish; bos_choch mendeteksi BOS dan CHoCH; liquidity_sweep mendeteksi sweep dengan validasi close back; session_filter mengklasifikasi sesi dengan benar; smc_pipeline menggabungkan semua deteksi; SMCAnalyzer menghasilkan setup dengan entry, SL, TP; setup hanya muncul saat sweep + OB + bias searah + sesi tradeable; semua unit test lulus; SMC analysis bisa dipanggil dari OpenCode; logging aktif setiap analisis; visualisasi chart dengan OB, FVG, sweep yang ditandai. Sprint 3a dinyatakan selesai saat deteksi STABIL, bukan saat modul pertama jalan.'),
    ('Estimasi waktu', '12 task: swing detector 2 jam, order block 3 jam, FVG 2 jam, BOS/CHoCH 3 jam, liquidity sweep 3 jam, session filter 1 jam, SMC pipeline 3 jam, skill OpenCode 2 jam, unit test 4 jam, visualisasi 2 jam, debugging & tuning 5 jam, dokumentasi 1 jam \u2014 TOTAL ~31 jam, dipecah 3-4 minggu @ 8 jam/minggu. Setelah 3a siap, lanjut 3b (generator sinyal + integrasi makro, 15-20 jam) lalu 3c (eksekusi).'),
  ];

  static const _rowsSP4 = <(String, String)>[
    ('Tujuan', 'Fase 3b: gabungkan semua deteksi + konteks menjadi sinyal trading. Estimasi 15-20 jam. Deliverables: signal_generator.py, signal_validator.py, logging sinyal ke logs/signals/, backtest sederhana utk hitung frekuensi sinyal/hari. Milestone: tanya "Apakah ada sinyal BUY XAUUSD sekarang?" \u2192 jawaban entry, SL, TP + alasan.'),
    ('Pipeline', 'Data harga + deteksi SMC (Sprint 3) + makro/musiman (Sprint 2) \u2192 signal_generator \u2192 signal_validator \u2192 log. Generator fokus pada kelengkapan & konsistensi sinyal; validator fokus pada kelayakan eksekusi (spread, sesi, konflik makro). Keluaran: action BUY/SELL/HOLD + entry/SL/TP/RR + confidence + reason (daftar alasan).'),
    ('Aturan sinyal', 'HOLD adalah default \u2014 sistem proaktif hanya saat setup kuat. Sinyal hanya bila: OB/FVG valid + BOS/CHoCH konfirmasi + sesi London/NY + tidak konflik bias makro. Entry: OB-mid (bukan harga pasar pas); SL: di luar struktur dgn buffer; TP: RR 1:3, bukan angka acak.'),
    ('Confidence', 'Skor 0-1 dari bobot: konfluensi SMC (OB+FVG+sweep), konfirmasi BOS/CHoCH, dukungan makro (DXY/VIX), bias musiman/sesi, dan jarak ke event risk. Contoh: OB+FVG+sweep+BOS + makro netral = confidence tinggi. Cutoff di validator (mis. >= 0.6). Reason wajib tercantum supaya keputusan bisa diaudit.'),
    ('Validator', 'signal_validator.py menolak bila: sesi tidak aktif; spread > 0.60 saat akan market order; jam < 30-60 menit sebelum rilis berita; konflik makro kuat (bias bulanan / korelasi DXY berlawanan); sudah lewat daily trade limit. Hasil: approved / rejected + alasan \u2014 semua terekam di audit trail.'),
    ('Logging sinyal', 'Setiap sinyal \u2192 logs/signals/ dgn event_type=signal, action, entry, SL, TP, confidence, session, reason[]. Log BOTH approved & rejected. Ini bahan backtest dan forward-test nanti \u2014 format harus bisa dibaca ulang & di-query (JSON), bukan sekadar print ke terminal.'),
    ('Backtest frekuensi', 'Jalankan generator pada data historis utk lihat: berapa sinyal/hari? Distribusi per sesi? Target 1-3 sinyal/hari. Terlalu banyak (10+) = permisif; terlalu sedikit (nol dalam seminggu) = terlalu ketat. Frekuensi dijaga lewat ambang confidence & jumlah konfluensi, bukan hardcode banyak rule.'),
    ('Integrasi & uji', 'Uji: "Apakah ada sinyal BUY XAUUSD sekarang?" \u2192 OpenCode menjalankan pipeline dan menjawab dgn angka. Test: action dalam BUY/SELL/HOLD; jika bukan HOLD, entry/SL/TP tidak None dgn SL di bawah entry utk BUY (dan sebaliknya utk SELL); confidence > 0. Rantai lengkap: data \u2192 deteksi \u2192 konfirmasi \u2192 output yang siap dieksekusi di Sprint 5.'),
    ('Pitfall & checklist', 'Pitfall #1: generator terlalu permisif \u2192 noise. Pitfall #2: terlalu ketat \u2192 sistem nganggur tak bertransaksi. Tuning lewat confidence threshold & jumlah konfluensi, ukur dgn backtest frekuensi 20-30 hari. Checklist: generator + validator selesai; log JSON benar; target 1-3 sinyal/hari tercapai; uji lulus; docs diperbarui.'),
  ];

  static const _rowsSP5 = <(String, String)>[
    ('Tujuan', 'Fase 3c: order besar dipecah dan dieksekusi tanpa merusak harga. Estimasi 25-35 jam. Deliverables: spread_filter, vwap_algo, twap_algo, order_router, slippage_monitor + test di demo (order kecil, verifikasi fill). Milestone: eksekusi order 0.10 lot XAUUSD di demo via VWAP dalam 5 menit.'),
    ('Mengapa split', 'Market order besar = market impact (harga bergerak melawan). Solusi: parent order dipecah jadi child order kecil terjadwal oleh algoritma. Dua pola: VWAP (eksekusi seiring volume pasar) dan TWAP (bagi merata per waktu). Default kita: VWAP horizon 60 menit utk size lebih dari 0.10 lot.'),
    ('Spread filter', 'spread_filter.py: cek spread saat ini vs ambang normal (0.30) dan volatile (0.60); blokir eksekusi jika melebar (menjelang berita/gap); output can_execute bool + reason. Spread adalah biaya tersembunyi XAUUSD \u2014 jangan eksekusi saat biayanya mahal.'),
    ('VWAP/TWAP algo', 'vwap_algo.py: hitung VWAP pasar pada horizon, pecahkan child order saat harga menguntungkan relatif VWAP. twap_algo.py: bagi volume merata per interval (default 5-10 menit). Keduanya kirim limit/pending, hindari market order. Parameter utama: total_volume, horizon, interval child, max_participation 0.15.'),
    ('Order router', 'order_router.py: jembatan tunggal ke MT5 \u2014 kirim child order dgn magic number khusus (label sistem), tangani retry & partial fill, laporkan status ke log. Semua order wajib lewat router supaya monitoring slippage & TCA terpusat, bukan order tersebar di banyak fungsi.'),
    ('Slippage monitor', 'slippage_monitor.py: catat slippage tiap fill = harga fill vs harga acuan (arrival); simpan dgn ukuran volume. Ambang: slippage > 0.30 \u2192 alert MEDIUM; konsisten lebih dari 2x model \u2192 review broker/algo. Data slippage adalah input utama TCA di Sprint 10.'),
    ('Test di demo', 'test_spread_filter: can_execute bertipe bool. test_vwap_executor: kirim 0.10 lot via VWAP horizon 5 menit \u2192 positions_get(symbol=XAUUSD) harus len > 0 \u2192 lalu close posisi. Semua test di akun DEMO; pantau fill rate & slippage aktual yang tercatat di log, bukan hasil "berhasil submit".'),
    ('Pitfall & tuning', 'Pitfall: child order terlalu cepat \u2192 market impact tetap besar; terlalu lambat \u2192 harga sudah menjauh dan target volume terlewat. Tuning interval child order: mulai 5 menit utk VWAP 60 menit, amati fill rate & slippage, sesuaikan 1-10 menit dgn catatan. Ukur kualitas eksekusi setelah 20-30 eksekusi, bukan dari 1 trade.'),
    ('Checklist & integrasi', 'Aturan dari agent_instructions: JANGAN market order utk size > 0.10 lot \u2014 wajib lewat algo. Checklist: 5 modul selesai; test demo lulus (kirim, fill, close); slippage & fill rate terekam; max_participation ditaati; docs diperbarui. Keluar sprint saat eksekusi konsisten dan tercatat, bukan hanya "bisa kirim order".'),
  ];

  static const _rowsSP6 = <(String, String)>[
    ('Tujuan', 'Fase 4: pertahanan berlapis SEBELUM eksekusi. Estimasi 30-40 jam. Deliverables: position_sizing, daily_limits, drawdown_guard, correlation_monitor, news_filter, kill_switch, recovery_protocol + risk_engine orkestrator + unit test tiap modul. Milestone: tidak ada order yang lolos tanpa validasi risk.'),
    ('Position sizing', 'Sizing berbasis ATR: volume = (equity x risk_per_trade) / (jarak SL x contract size). Contoh unit test: risk 1%, equity 10.000 USD, entry 2345, SL 2340 (jarak 5) \u2192 100 / (5 x 100) = 0.20 lot \u2014 test menerima 0.18-0.22. Risk per trade default 1%, maksimal 2%.'),
    ('Daily limits', 'daily_limits.py: max_daily_loss 3%, max_daily_profit 6%, max_trades 10/hari; initialize_day saat sesi dibuka; can_trade(equity) \u2192 bool + alasan. Test: equity turun 3.5% dari 10.000 \u2192 can_trade False dgn alasan mengandung "loss limit". State harian harus persisten (tidak hilang saat restart).'),
    ('Drawdown guard', 'drawdown_guard.py: circuit breaker 4 level dari equity peak \u2014 5% \u2192 kurangi size 25%, 10% \u2192 size 50%, 15% \u2192 pause trading, 20% (level 4) \u2192 KILL SWITCH: tutup semua posisi & setop. Test: DD 8% \u2192 action reduce_25. Peak equity dilacak sejak start dan hanya naik (ratchet).'),
    ('Correlation & news', 'correlation_monitor.py: cek exposure agregat bila holding beberapa aset (XAU vs XAG vs US10Y); batasi risiko satu arah. news_filter.py: window rilis high impact dari release_calendar (Sprint 2) \u2192 blok entry 30-60 menit sebelum; ini yang membuat bot pause PADA WAKTUNYA, bukan reaktif.'),
    ('Kill switch & recovery', 'kill_switch.py: flag kill_switch.json \u2014 saat aktif, semua eksekusi diblok & posisi ditutup; hanya bisa dinonaktifkan lewat prosedur manual setelah root cause jelas. recovery_protocol.py: setelah insiden DD, resume trading dgn size 25% dulu lalu naik bertahap sampai pulih normal \u2014 bukan langsung size penuh.'),
    ('Risk engine', 'risk_engine.py sbg orkestrator: urutan gate per sinyal \u2014 sizing \u2192 daily limits \u2192 drawdown \u2192 correlation \u2192 news filter \u2192 kill switch. Output: approved(volume) atau rejected(reason). OrderRouter HANYA menerima hasil engine \u2014 tak ada jalur pintas. Log tiap keputusan ke audit trail.'),
    ('Pitfall & tuning', 'Pitfall: terlalu ketat \u2192 tidak ada trade; terlalu longgar \u2192 tidak berguna. Mulai dari nilai default (risk 1%, DD 5/10/15/20), lalu tuning HANYA SETELAH minimal 100 trade (beberapa siklus cukup). Tuning tiap 5 trade = curve-fitting terhadap risk engine. Catat setiap perubahan parameter di docs.'),
    ('Checklist & integrasi', 'Unit test wajib: sizing utk 10.000/SL 5 menghasilkan 0.18-0.22; daily_limits memblokir loss 3.5%; drawdown_guard memberi reduce_25 di DD 8%. Integrasi: sinyal (Sprint 4) \u2192 risk engine \u2192 router (Sprint 5). Checklist: 8 modul + test lulus; state harian persisten; kill switch teruji; docs diperbarui.'),
  ];

  static const _rowsSP7 = <(String, String)>[
    ('Tujuan', 'Fase 5a: sistem diuji pada data historis dengan biaya realistis. Estimasi 40-50 jam. Deliverables: data XAUUSD M15 2020-2025 dari MT5, cost_model.py, custom engine.py, metrics.py, vectorbt_runner.py, laporan backtest pertama. Milestone: laporan berisi Sharpe, Max DD, dan Profit Factor.'),
    ('Data historis', 'Download dari MT5: XAUUSD M15 2020-2025, pastikan bersih (gap weekend, harga salah), simpan parquet/sqlite. Sumber data SAMA dgn yang dipakai pas trading (broker yang sama) supaya hasil konsisten. 5 tahun M15 berukuran besar \u2014 butuh storage & pipeline download bertahap.'),
    ('Cost model', 'cost_model.py menghitung biaya per trade: spread/2 x lot x contract size, komisi per lot, slippage per fill, swap bila overnight. Uji unit: spread 0.30/2 x 0.20 x 100 = 3.00; komisi 5 x 0.20 = 1.00; slippage 0.10 x 0.20 x 100 = 2.00 \u2192 total 6.00 (diterima 5.5-6.5). Tanpa cost model, backtest = hasil fiktif.'),
    ('Engine', 'engine.py: jalankan strategi pada bar chart \u2014 feed sinyal \u2192 risk engine \u2192 eksekusi \u2192 hasilkan equity curve & daftar trade. WAJIB memakai risk engine yang sama persis dgn live (bukan versi ringan). Test: equity_curve len > 0 dan daftar trade tidak kosong.'),
    ('Metrik', 'metrics.py: Sharpe, Sortino, Max DD (absolut & %), Profit Factor, win rate, avg R, exposure, turnover. Simpan metrik beserta config parameter tiap run supaya perbandingan antar run konsisten. Laporan pertama: tabel metrik + grafik equity curve & drawdown.'),
    ('VectorBT', 'vectorbt_runner.py utk EKSPLORASI cepat (param sweep, portfolio) \u2014 bukan pengganti engine kustom utk keputusan. VectorBT kurang fleksibel utk mapping risk engine & kustomisasi eksekusi; setiap hasil menarik dari VectorBT harus divalidasi ulang di engine.py.'),
    ('Backtest = batas', 'Pitfall #1: terlalu optimis. Ingat: backtest adalah LOWER BOUND (estimasi kasus terbaik), bukan prediksi. Cek: slippage & spread model realistis; tidak ada data snooping; biaya tidak diabaikan; hasil "ajaib" (Sharpe 10+) lebih sering bug atau overfit daripada keunggulan nyata.'),
    ('Pipeline reproducible', 'Repetisi yang konsisten: data bersih \u2192 engine \u2192 metrik \u2192 laporan (dgn config & seed). Simpan semua run di backtest/results supaya siap dibandingkan di WFO (Sprint 8). Reproducible: seed tetap, versi data & parameter tercatat. Setiap perubahan kode strategi = run baru.'),
    ('Checklist & integrasi', 'Checklist: data M15 2020-2025 tersimpan & bersih; cost model lulus uji 6.00; engine memakai risk engine nyata; metrik lengkap; laporan pertama selesai; VectorBT siap utk eksplorasi. Integrasi utk Sprint 8: struktur output sudah dirancang utk WFO & Monte Carlo (trades + equity curve + params).'),
  ];

  static const _rowsSP8 = <(String, String)>[
    ('Tujuan', 'Fase 5b: membuktikan strategi tidak overfit dan robust. Estimasi 30-40 jam. Deliverables: WFO minimal 4 window OOS, Monte Carlo trade shuffling & bootstrap (10.000 simulasi), parameter perturbation test, analisis per regime & sesi, Deflated Sharpe Ratio, laporan validasi lengkap. Milestone: bukti statistik layak live ATAU bukti strategi perlu diperbaiki.'),
    ('Walk-Forward', 'WFO: optimasi parameter di window in-sample, tes di window out-of-sample berikutnya, lalu geser maju; minimal 4 window OOS. Kriteria lulus: mean OOS Sharpe > 0.5 dan lebih dari 60% window OOS positif. Hasil backtest "bagus" tanpa WFO belum membuktikan apa-apa.'),
    ('Monte Carlo', 'Dua jenis wajib: trade shuffling (acak urutan trade 10.000x \u2192 distribusi equity & prob of profit) dan bootstrap return (distribusi metrik). Kriteria: prob_profit > 0.8 dan p95 Max DD < 0.30. Monte Carlo menguji keragaman urutan, WFO menguji keragaman data \u2014 keduanya berbeda, keduanya wajib.'),
    ('Perturbation', 'Parameter perturbation test: geser tiap parameter +/- 1 step, amati degradasi performa. Robust = perubahan kecil tidak mengubah hasil signifikan. Ciri overfit klasik: performa anjlok drastis saat parameter digeser satu langkah.'),
    ('Regime & sesi', 'Analisis per regime pasar (tren, range, volatilitas) dan per sesi (London/NY/Asia): di mana strategi untung dan rugi. Hasil difilter ke sesi yang terbukti untung. Jika strategi hanya menang di satu regime, keputusan live harus sadar regime \u2014 jangan asumsi pasar selalu tren.'),
    ('Deflated Sharpe', 'DSR = Sharpe yang dikoreksi jumlah trial (multiple testing). Makin besar parameter grid & jumlah eksplorasi, makin besar koreksi. Gate: DSR > 0.95 baru layak lanjut. DSR rendah setelah banyak eksplorasi parameter = tanda overfit tersembunyi.'),
    ('Tidak sabar = musuh', 'Pitfall #1: tidak sabar \u2014 skip WFO karena "hasil in-sample sudah bagus". Validasi memang butuh waktu dan itu normal. Jalani semua step berurutan dan catat setiap hasil pass/fail di laporan \u2014 jangan hanya melaporkan yang bagus (survivorship bias).'),
    ('Laporan validasi', 'Struktur laporan: data & periode; konfigurasi WFO (window, param grid); hasil in-sample vs OOS per window; Monte Carlo (prob profit, p95 DD); ringkasan perturbation; analisis regime/sesi; DSR; kesimpulan layak / rebuild. Semua run tersimpan di backtest/results utk audit.'),
    ('Checklist & keluar', 'Checklist: WFO >= 4 window dgn kriteria lulus; Monte Carlo 10.000 simulasi lolos threshold; perturbation stabil; analisis regime/sesi selesai; DSR > 0.95; laporan lengkap. Keluar Sprint 8 = keputusan tegas: LAYAK ke Sprint 9 atau kembali review \u2014 tidak ada status "agak layak".'),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = switch (_topic) {
      0 => _rows,
      1 => _rowsSM,
      2 => _rowsEO,
      3 => _rowsPA,
      4 => _rowsIM,
      5 => _rowsOP,
      6 => _rowsMT,
      7 => _rowsDATA,
      8 => _rowsST,
      9 => _rowsRK,
10 => _rowsBT,
       11 => _rowsDP,
       12 => _rowsRM,
       13 => _rowsSP0,
       14 => _rowsSP1,
       15 => _rowsSP2,
       16 => _rowsSP3,
       17 => _rowsSP4,
       18 => _rowsSP5,
       19 => _rowsSP6,
       20 => _rowsSP7,
       21 => _rowsSP8,
       _ => _rowsOP,
    };
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
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 10),
            _topicToggle(),
            const SizedBox(height: 12),
            for (final r in rows)
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
            const SizedBox(height: 4),
            if (_topic == 0)
              const Text('Semua angka berasal dari data harian, bukan saran trading. Verifikasi selalu dengan disiplin risiko.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic))
            else
              const Text('Sinyal dihitung dari data harga, bukan order flow institusi \u2014 probabilitas, bukan kepastian. Edukasi, bukan saran.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _topicToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _topicBtn(0, 'BACA SINYAL'),
            _topicBtn(1, 'SMART MONEY'),
            _topicBtn(2, 'ALUR ORDER'),
            _topicBtn(3, 'PER ASET'),
            _topicBtn(4, 'OPERASI'),
            _topicBtn(5, 'IMPLEMENTASI'),
            _topicBtn(6, 'SETUP MT5'),
            _topicBtn(7, 'SETUP DATA'),
            _topicBtn(8, 'STRATEGI'),
            _topicBtn(9, 'RISIKO'),
            _topicBtn(10, 'BACKTEST'),
             _topicBtn(11, 'DEPLOY'),
             _topicBtn(12, 'ROADMAP'),
             _topicBtn(13, 'SPRINT 0'),
             _topicBtn(14, 'SPRINT 1'),
             _topicBtn(15, 'SPRINT 2'),
             _topicBtn(16, 'SPRINT 3'),
             _topicBtn(17, 'SPRINT 4'),
             _topicBtn(18, 'SPRINT 5'),
             _topicBtn(19, 'SPRINT 6'),
             _topicBtn(20, 'SPRINT 7'),
             _topicBtn(21, 'SPRINT 8'),
          ],
        ),
      ),
    );
  }

  Widget _topicBtn(int t, String label) {
    final selected = _topic == t;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _topic = t;
          _open = true;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.blue : AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
