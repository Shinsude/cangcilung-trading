part of 'package:cangcilung_trading/screens/home_screen.dart';

class _LoadingView extends StatefulWidget {
  const _LoadingView();
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_ctrl),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _SkeletonCard(height: 120, radius: 22),
          SizedBox(height: 14),
          _SkeletonCard(height: 210, radius: 22),
          SizedBox(height: 14),
          _SkeletonCard(height: 150, radius: 16),
          SizedBox(height: 14),
          _SkeletonCard(height: 60, radius: 16),
          SizedBox(height: 14),
          _SkeletonCard(height: 90, radius: 16),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 90, height: 10, decoration: _line(8)),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 12, decoration: _line(8)),
          const SizedBox(height: 10),
          Container(width: 160, height: 12, decoration: _line(8)),
          const Spacer(),
          Container(width: double.infinity, height: 8, decoration: _line(4)),
        ],
      ),
    );
  }

  BoxDecoration _line(double r) => BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(r),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceAlt,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Gagal Memuat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandleTimer extends StatefulWidget {
  const _CandleTimer();
  @override
  State<_CandleTimer> createState() => _CandleTimerState();
}

class _CandleTimerState extends State<_CandleTimer> {
  Timer? _t;
  Duration _remaining = Duration.zero;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final mins = (now.minute ~/ 15 + 1) * 15 % 60;
    var next = DateTime(now.year, now.month, now.day, now.hour, mins);
    if (next.isBefore(now)) {
      next = next.add(const Duration(hours: 1));
    }
    final d = next.difference(now);
    final prog = ((900 - d.inSeconds) / 900).clamp(0.0, 1.0);
    if (mounted && (d != _remaining || prog != _progress)) {
      setState(() {
        _remaining = d;
        _progress = prog;
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('M15 CLOSE', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const Spacer(),
              Text(_mmss, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              backgroundColor: AppColors.surfaceAlt,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.system});
  final SystemHealth system;

  String get _tsLabel {
    final i = system.tsIntrinsic;
    if (i >= 60) return 'STRONG';
    if (i >= 40) return 'MED';
    if (i > 5) return 'WEAK';
    return 'NOISE';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text('SISTEM HEALTH', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          _row('TS', '$_tsLabel ${system.tsIntrinsic.toStringAsFixed(0)}%',
              system.tsIntrinsic >= 40 ? AppColors.green : system.tsIntrinsic >= 25 ? AppColors.amber : AppColors.red),
          _row('SNR', '${system.tsSnr.toStringAsFixed(1)}x',
              system.tsSnr >= 1.5 ? AppColors.green : system.tsSnr >= 0.8 ? AppColors.amber : AppColors.red),
          _row('DECOMP', system.decompRegime,
              system.decompRegime == 'TRENDING' ? AppColors.green : system.decompRegime == 'RANGING' ? AppColors.amber : AppColors.red),
          _row('BAR', '${system.barTotal.toStringAsFixed(0)}/100',
              system.barTotal >= 70 ? AppColors.green : system.barTotal >= 40 ? AppColors.amber : AppColors.red),
          const SizedBox(height: 4),
          const Divider(color: AppColors.border, height: 14),
          Row(
            children: [
              const Text('THETA', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${system.theta.label} Â· AI ${system.theta.aiDir == 0 ? 'â€“' : system.theta.aiDir > 0 ? 'â–²' : 'â–¼'} vs RULES ${system.theta.rulesDir == 0 ? 'â€“' : system.theta.rulesDir > 0 ? 'â–²' : 'â–¼'}',
                  style: TextStyle(
                    color: system.theta.aligned ? AppColors.green : AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _row('SAFE', system.safety.status,
              system.safety.status == 'OK' ? AppColors.green : system.safety.status == 'N/A' ? AppColors.textSecondary : AppColors.red),
          if (system.safety.violations > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 44),
              child: Text('âš  ${system.safety.violations} pelanggaran Â· SL min ${system.safety.minimumStop.toStringAsFixed(0)} Â· RR ${system.safety.riskReward.toStringAsFixed(1)}',
                  style: const TextStyle(color: AppColors.red, fontSize: 9)),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 40, child: Text(k, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
            Text(v, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
class _SessionTimeline extends StatefulWidget {
  const _SessionTimeline();
  @override
  State<_SessionTimeline> createState() => _SessionTimelineState();
}

class _SessionTimelineState extends State<_SessionTimeline> {
  Timer? _t;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _tick();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  void _tick() {
    final n = DateTime.now().toUtc();
    if (mounted && n != _now) setState(() => _now = n);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  static final List<int> _asia = [for (var h = 0; h < 9; h++) h];
  static final List<int> _london = [for (var h = 8; h < 17; h++) h];
  static final List<int> _ny = [for (var h = 13; h < 22; h++) h];

  Color _hourColor(int h) {
    final inA = _asia.contains(h), inL = _london.contains(h), inN = _ny.contains(h);
    if (inA && inL) return AppColors.blue;
    if (inL && inN) return AppColors.purple;
    if (inA) return AppColors.blue.withValues(alpha: 0.55);
    if (inL) return AppColors.green.withValues(alpha: 0.55);
    if (inN) return AppColors.amber.withValues(alpha: 0.55);
    return AppColors.surfaceAlt;
  }

  String get _sessionLabel {
    final h = _now.hour + _now.minute / 60.0;
    final active = <String>[];
    if (h >= 0 && h < 9) active.add('ASIA');
    if (h >= 8 && h < 17) active.add('LONDON');
    if (h >= 13 && h < 22) active.add('NEW YORK');
    if (active.isEmpty) return 'CLOSED';
    if (active.length == 2) return '${active[0]} â†’ ${active[1]}';
    return active.first;
  }

  Color get _sessionColor {
    final s = _sessionLabel;
    if (s.contains('ASIA') && s.contains('LONDON')) return AppColors.blue;
    if (s.contains('NEW YORK') && s.contains('LONDON')) return AppColors.purple;
    if (s.contains('ASIA')) return AppColors.blue;
    if (s.contains('LONDON')) return AppColors.green;
    if (s.contains('NEW YORK')) return AppColors.amber;
    return AppColors.textSecondary;
  }

  String get _bestMomentLabel {
    final h = _now.hour + _now.minute / 60.0;
    final events = <double, String>{
      8.0: 'ASIA+LONDON overlap MULAI',
      13.0: 'LONDON+NEW YORK overlap MULAI',
      17.0: 'LONDON tutup',
      22.0: 'NEW YORK tutup',
    };
    double? next;
    String? label;
    for (final e in events.entries) {
      if (e.key > h && (next == null || e.key < next)) {
        next = e.key;
        label = e.value;
      }
    }
    double mins;
    if (next == null) {
      mins = (24 + 8 - h) * 60;
      label = 'ASIA+LONDON overlap MULAI';
    } else {
      mins = (next - h) * 60;
    }
    final m = mins.round();
    return '$label dalam ${m ~/ 60}j ${m % 60}m';
  }

  Color get _bestMomentColor {
    final l = _bestMomentLabel;
    if (l.startsWith('LONDON+NEW YORK')) return AppColors.purple;
    if (l.startsWith('ASIA+LONDON')) return AppColors.blue;
    if (l.startsWith('LONDON tutup')) return AppColors.green;
    return AppColors.amber;
  }

  Widget _legendDot(Color c) => Container(width: 6, height: 6, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  @override
  Widget build(BuildContext context) {
    final frac = (_now.hour + _now.minute / 60.0) / 24.0;
    return Container(
      padding: const EdgeInsets.all(12),
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
              const Text('SESI TRADING', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _sessionColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_sessionLabel, style: TextStyle(color: _sessionColor, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 18,
              child: Stack(
                children: [
                  Row(
                    children: [
                      for (var h = 0; h < 24; h++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(color: _hourColor(h), borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: c.maxWidth * frac - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(1))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(AppColors.blue),
              const SizedBox(width: 4),
              const Text('ASIA', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              _legendDot(AppColors.green),
              const SizedBox(width: 4),
              const Text('LONDON', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              _legendDot(AppColors.amber),
              const SizedBox(width: 4),
              const Text('NEW YORK', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              _legendDot(AppColors.purple),
              const SizedBox(width: 4),
              const Text('OVERLAP', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _bestMomentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 13, color: _bestMomentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'MOMEN TERBAIK: $_bestMomentLabel',
                    style: TextStyle(color: _bestMomentColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
