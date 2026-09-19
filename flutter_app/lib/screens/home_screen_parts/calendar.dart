part of 'package:cangcilung_trading/screens/home_screen.dart';

class _CalendarSection extends StatefulWidget {
  const _CalendarSection({super.key, required this.api});

  final ApiService api;

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  List<EconomicEvent>? _events;
  String? _error;
  Timer? _timer;
  bool _hideMedium = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<EconomicEvent> get _filteredEvents {
    if (_events == null) return const [];
    if (!_hideMedium) return _events!;
    return _events!.where((e) => e.impact.toLowerCase() == 'high').toList();
  }

  Future<void> reload() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final ev = await widget.api.fetchCalendar();
      if (!mounted) return;
      setState(() {
        _events = ev;
        _error = null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  static String _countdown(DateTime now, int ts) {
    final diff = ts - now.millisecondsSinceEpoch;
    if (diff <= 0) return 'sekarang';
    if (diff < 3600000) return '${(diff / 60000).floor()}m';
    if (diff < 86400000) return '${(diff / 3600000).floor()}J';
    return '${(diff / 86400000).floor()}H';
  }

  static String _dayLabel(DateTime now, int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff == 2) return 'Lusa';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KALENDER EKONOMI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text(
          'Event high & medium impact dari kalender ForexFactory untuk 48 jam ke depan (waktu WIB).',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('Sembunyikan impact Medium', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                height: 20,
                width: 36,
                child: Switch(
                  value: _hideMedium,
                  onChanged: (v) => setState(() => _hideMedium = v),
                  activeTrackColor: AppColors.blue.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textTertiary,
                  inactiveTrackColor: AppColors.surfaceAlt,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_events == null && _error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: AppColors.blue, strokeWidth: 3)),
          )
        else if (_events == null)
          _CalendarError(message: _error ?? 'Gagal memuat data', onRetry: _load)
        else if (_filteredEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                _hideMedium
                    ? 'Tidak ada event HIGH impact mendatang'
                    : 'Belum ada event high/medium impact mendatang',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          )
        else ...[
          ..._filteredEvents.map((e) => _EventTile(event: e, now: now)),
        ],
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.now});

  final EconomicEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final impact = event.impact.toLowerCase() == 'high';
    final impactColor = impact ? AppColors.red : AppColors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_CalendarSectionState._dayLabel(now, event.ts), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(event.timeWib, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                      child: Text(event.country, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    if (impact) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('HIGH', style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(event.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.25)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _CalendarSectionState._countdown(now, event.ts),
            style: TextStyle(color: impactColor, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            _ActionPill(label: 'Coba lagi', icon: Icons.refresh, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
