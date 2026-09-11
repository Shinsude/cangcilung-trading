import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/candle_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final List<String> _symbols = ['XAUUSD', 'NASDAQ', 'AUDUSD'];
  String _selected = 'XAUUSD';
  TradingData? _data;
  String? _error;
  bool _loading = true;
  bool _fetching = false;
  bool _live = false;
  int _tab = 0;
  ModelInfo? _model;
  bool _modelLoading = false;
  String? _modelError;
  bool _notifOn = false;
  bool _minimal = false;
  Timer? _signalWatcher;
  final Map<String, double> _alerts = {};
  final Map<String, List<double>> _confHistory = {};

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _load();
    _warmAndSeed();
    _loadModel();
    _initNotifPref();
    _initMinimalPref();
    _loadAlerts();
  }

  @override
  void dispose() {
    _signalWatcher?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initNotifPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool('notif_on') ?? false;
      if (!mounted) return;
      setState(() => _notifOn = on);
      if (on) _startSignalWatcher();
    } catch (_) {}
  }

  void _toggleNotif(bool on) async {
    setState(() => _notifOn = on);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_on', on);
    } catch (_) {}
    if (on) {
      await NotificationService.instance.enabledOnDevice();
      _startSignalWatcher();
      unawaited(_checkStrongSignals());
    } else {
      _signalWatcher?.cancel();
      _signalWatcher = null;
    }
  }

  void _startSignalWatcher() {
    _signalWatcher?.cancel();
    _signalWatcher = Timer.periodic(const Duration(minutes: 5), (_) => unawaited(_checkStrongSignals()));
  }

  Future<void> _initMinimalPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = prefs.getBool('minimal_mode') ?? false;
      if (!mounted) return;
      setState(() => _minimal = m);
    } catch (_) {}
  }

  Future<void> _toggleMinimal(bool on) async {
    setState(() => _minimal = on);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('minimal_mode', on);
    } catch (_) {}
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, double>{};
      for (final s in _symbols) {
        final v = prefs.getDouble('alert_$s');
        if (v != null && v > 0) map[s] = v;
      }
      if (!mounted) return;
      setState(() {
        _alerts
          ..clear()
          ..addAll(map);
      });
    } catch (_) {}
  }

  Future<void> _setAlert(String symbol) async {
    final controller = TextEditingController();
    final target = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.borderLight)),
        title: const Text('Alert Harga', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifikasi saat harga menembus level ini.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'contoh: 4600',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('Simpan', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (target == null || !target.isFinite || target <= 0 || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('alert_$symbol', target);
    setState(() => _alerts[symbol] = target);
  }

  Future<void> _clearAlert(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alert_$symbol');
    if (!mounted) return;
    setState(() => _alerts.remove(symbol));
  }

  Future<void> _checkPriceAlert(String symbol, double price) async {
    if (kIsWeb) return;
    final target = _alerts[symbol];
    if (target == null || target <= 0) return;
    if (price >= target) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alert_$symbol');
      if (!mounted) return;
      setState(() => _alerts.remove(symbol));
      await NotificationService.instance.showPriceAlert(symbol, target, price);
    }
  }

  Future<void> _checkStrongSignals() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final s in _symbols) {
        final TradingData data;
        try {
          data = await _api.fetchSignal(s, useCache: false);
        } catch (_) {
          continue;
        }
        final action = data.signal.action;
        final strength = data.signal.strength;
        unawaited(_checkPriceAlert(s, data.currentPrice));
        if (action != 'HOLD') {
          final sig = '$action|$strength';
          final last = prefs.getString('last_sig_$s') ?? '';
          if (sig != last) {
            await prefs.setString('last_sig_$s', sig);
            await NotificationService.instance.showStrongSignal(s, action, strength);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadModel() async {
    setState(() {
      _modelLoading = true;
      _modelError = null;
    });
    try {
      final model = await _api.fetchModel();
      if (!mounted) return;
      setState(() {
        _model = model;
        _modelLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _modelError = e.toString();
        _modelLoading = false;
      });
    }
  }

  Future<void> _warmAndSeed() async {
    await _api.warmup();
    if (!mounted) return;
    await Future.wait(_symbols.map((s) async {
      try {
        await _api.fetchSignal(s, useCache: false);
      } catch (_) {}
    }));
  }

  Future<void> _load() async {
    if (_data == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    setState(() => _fetching = true);

    final cached = await _api.readCachedSignal(_selected);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _data = cached;
        _loading = false;
      });
    }

    try {
      final data = await _api.fetchSignal(_selected, useCache: false);
      if (!mounted) return;
      final hist = _confHistory.putIfAbsent(_selected, () => []);
      hist.add(data.signal.confidence);
      if (hist.length > 15) hist.removeAt(0);
      setState(() {
        _data = data;
        _loading = false;
        _fetching = false;
        _live = true;
      });
      unawaited(_checkPriceAlert(_selected, data.currentPrice));
      Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _live = false);
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _fetching = false);
      if (_data == null) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _selectSymbol(String s) {
    if (s == _selected) return;
    setState(() => _selected = s);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(symbols: _symbols, selected: _selected, onSelect: _selectSymbol, live: _live || _fetching, notifyOn: _notifOn, onToggleNotify: _toggleNotif, minimal: _minimal, onToggleMinimal: _toggleMinimal),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _fetching ? 3 : 0,
              child: _fetching
                  ? const LinearProgressIndicator(
                      color: AppColors.blue,
                      backgroundColor: Colors.transparent,
                      minHeight: 3,
                    )
                  : null,
            ),
            Expanded(
              child: _loading
                  ? const _LoadingView()
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        padding: EdgeInsets.only(bottom: bottomPad),
        child: _BottomNav(
          tab: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: [
        _SignalPage(
          data: d,
          onRefresh: _load,
          pulse: _pulseCtrl,
          alertTarget: _alerts[d.symbol],
          onSetAlert: () => _setAlert(d.symbol),
          onClearAlert: () => _clearAlert(d.symbol),
          minimal: _minimal,
          confHistory: _confHistory[d.symbol] ?? const [],
        ),
        _ChartPage(data: d),
        _IndicatorsPage(ind: d.indicators, price: d.currentPrice, weights: d.weights),
        _CalendarPage(api: _api),
        _SentimentPage(sentiment: d.sentiment),
        _ModelPage(
          model: _model,
          loading: _modelLoading,
          error: _modelError,
          onRetry: _loadModel,
          notifyOn: _notifOn,
          onToggleNotify: _toggleNotif,
          api: _api,
        ),
      ][_tab],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.symbols, required this.selected, required this.onSelect, required this.live, required this.notifyOn, required this.onToggleNotify, required this.minimal, required this.onToggleMinimal});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool live;
  final bool notifyOn;
  final ValueChanged<bool> onToggleNotify;
  final bool minimal;
  final ValueChanged<bool> onToggleMinimal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.green, AppColors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.candlestick_chart, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cangcilung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
                  Text('TRADING AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 9, color: AppColors.textSecondary, letterSpacing: 1.5)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const _GuideSheet(),
                ),
                icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 22),
                tooltip: 'Cara Pakai',
              ),
              _NotifButton(on: notifyOn, onToggle: onToggleNotify),
              _MinimalButton(minimal: minimal, onToggle: onToggleMinimal),
              const SizedBox(width: 10),
              _LiveIndicator(live: live),
            ],
          ),
          const SizedBox(height: 12),
          _SymbolBar(symbols: symbols, selected: selected, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.on, required this.onToggle});
  final bool on;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = on ? AppColors.blue : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => onToggle(!on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18, color: c),
      ),
    );
  }
}

class _MinimalButton extends StatelessWidget {
  const _MinimalButton({required this.minimal, required this.onToggle});
  final bool minimal;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = minimal ? AppColors.amber : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => onToggle(!minimal),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Icon(minimal ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: c),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = live ? AppColors.green : AppColors.textTertiary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: live ? [const BoxShadow(color: AppColors.green, blurRadius: 8, spreadRadius: 1)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            live ? 'LIVE' : 'OFFLINE',
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _SymbolBar extends StatelessWidget {
  const _SymbolBar({required this.symbols, required this.selected, required this.onSelect});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in symbols) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: s != symbols.last ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: s == selected ? AppColors.blue.withValues(alpha: 0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s == selected ? AppColors.blue.withValues(alpha: 0.4) : AppColors.border,
                  ),
                  boxShadow: s == selected ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.12), blurRadius: 12)] : null,
                ),
                child: Column(
                  children: [
                    Text(
                      s,
                      style: TextStyle(
                        color: s == selected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: s == selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s == selected ? AppColors.blue : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onChanged});

  final int tab;
  final ValueChanged<int> onChanged;

  static const _icons = [Icons.auto_graph, Icons.candlestick_chart, Icons.insights, Icons.event_rounded, Icons.newspaper, Icons.psychology_rounded];
  static const _labels = ['Signal', 'Chart', 'Indikator', 'Kalender', 'Sentimen', 'Model'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(6, (i) {
        final active = i == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[i],
                    size: 22,
                    color: active ? AppColors.blue : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.blue : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

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
                  '${system.theta.label} · AI ${system.theta.aiDir == 0 ? '–' : system.theta.aiDir > 0 ? '▲' : '▼'} vs RULES ${system.theta.rulesDir == 0 ? '–' : system.theta.rulesDir > 0 ? '▲' : '▼'}',
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
              child: Text('⚠ ${system.safety.violations} pelanggaran · SL min ${system.safety.minimumStop.toStringAsFixed(0)} · RR ${system.safety.riskReward.toStringAsFixed(1)}',
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
    if (active.length == 2) return '${active[0]} → ${active[1]}';
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
        ],
      ),
    );
  }
}

class _SignalPage extends StatelessWidget {
  const _SignalPage({required this.data, required this.onRefresh, required this.pulse, required this.alertTarget, required this.onSetAlert, required this.onClearAlert, this.minimal = false, this.confHistory = const []});

  final TradingData data;
  final Future<void> Function() onRefresh;
  final AnimationController pulse;
  final double? alertTarget;
  final VoidCallback onSetAlert;
  final VoidCallback onClearAlert;
  final bool minimal;
  final List<double> confHistory;

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
                : const Text('Setel alert harga (notifikasi saat tembus level)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
    final arrow = prediction.direction == 'UP' ? 'â–²' : prediction.direction == 'DOWN' ? 'â–¼' : 'â—†';
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
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% Â· ${prediction.horizon}',
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
      'Sinyal: ${signal.action} (${signal.strength}) · ${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
      'Harga: ${price.toStringAsFixed(decimals)}',
      'Prediksi ${prediction.horizon}: ${prediction.direction == 'UP' ? 'naik' : prediction.direction == 'DOWN' ? 'turun' : 'netral'} → ${prediction.nextPrice.toStringAsFixed(decimals)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
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
          const Text('Simulasi dari sinyal terakhir — bukan akun MT5 live.', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4)),
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

class _ChartPage extends StatelessWidget {
  const _ChartPage({required this.data});
  final TradingData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
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
                  const Icon(Icons.candlestick_chart, size: 18, color: AppColors.blue),
                  const SizedBox(width: 8),
                  const Text('Price Chart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                    child: Text('${data.candles.length} candles', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CandleChart(candles: data.candles, decimals: data.decimals, risk: data.risk),
            ],
          ),
        ),
      ],
    );
  }
}

class _IndicatorsPage extends StatelessWidget {
  const _IndicatorsPage({required this.ind, required this.price, this.weights = const {}});

  final Indicators ind;
  final double price;
  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final rsiColor = ind.rsi.value < 30
        ? AppColors.green
        : ind.rsi.value > 70
            ? AppColors.red
            : AppColors.amber;
    final bbPos = ind.bollinger.percentB ?? 0.5;
    final bbPosColor = bbPos < 0.3 ? AppColors.green : bbPos > 0.7 ? AppColors.red : AppColors.amber;
    final macdColor = ind.macd.histogram >= 0 ? AppColors.green : AppColors.red;
    final emaColor = ind.ema.trend == 'bullish' ? AppColors.green : AppColors.red;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('INDIKATOR TEKNIKAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            _IndicatorTile(icon: Icons.speed_rounded, label: 'RSI (14)', value: ind.rsi.value.toStringAsFixed(1), sub: ind.rsi.region, color: rsiColor),
            _IndicatorTile(icon: Icons.show_chart_rounded, label: 'MACD', value: ind.macd.histogram.toStringAsFixed(4), sub: ind.macd.cross ?? 'neutral', color: macdColor),
            _IndicatorTile(icon: Icons.trending_up_rounded, label: 'EMA Trend', value: ind.ema.trend, sub: '9/21/50', color: emaColor),
            _IndicatorTile(icon: Icons.bolt_rounded, label: 'Bollinger %B', value: bbPos.toStringAsFixed(2), sub: 'Upper ${ind.bollinger.upper.toStringAsFixed(2)}', color: bbPosColor),
            _IndicatorTile(icon: Icons.waves_rounded, label: 'Volatilitas', value: '${(ind.volatility20 * 100).toStringAsFixed(2)}%', sub: 'SMA20 ${ind.sma20.toStringAsFixed(2)}', color: AppColors.purple),
            _IndicatorTile(icon: Icons.straighten_rounded, label: 'ATR (14)', value: ind.atr != null ? ind.atr!.toStringAsFixed(ind.atr! < 1 ? 5 : 2) : '—', sub: 'Dasar SL/TP', color: AppColors.amber),
            _IndicatorTile(icon: Icons.speed_rounded, label: 'SMA 20', value: ind.sma20.toStringAsFixed(2), sub: 'Harga: ${price.toStringAsFixed(2)}', color: AppColors.blue),
          ],
        ),
        const SizedBox(height: 20),
        const Text('BOBOT MODEL (AUTO-TUNE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text(
          'Bobot hasil walk-forward backtest per simbol: indikator yang paling akurat diperkuat (hijau), yang paling lemah diredam (biru).',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (weights.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weights.entries.map((e) => _WeightChip(label: e.key, weight: e.value)).toList(),
          )
        else
          const Text('Belum tersedia', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      ],
    );
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.label, required this.weight});
  final String label;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (weight > 1.05) {
      color = AppColors.green;
    } else if (weight < 0.95) {
      color = AppColors.blue;
    } else {
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(weight.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, fontFeatures: const [FontFeature.tabularFigures()]),
            overflow: TextOverflow.ellipsis,
          ),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

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

class _CalendarPage extends StatefulWidget {
  const _CalendarPage({required this.api});

  final ApiService api;

  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
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
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text('KALENDER EKONOMI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text(
            'Event high & medium impact dari kalender ForexFactory untuk 48 jam ke depan (waktu WIB).',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4),
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
      ),
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
                Text(_CalendarPageState._dayLabel(now, event.ts), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
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
                      child: Text(event.country, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    if (impact) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('HIGH', style: TextStyle(color: AppColors.red, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
            _CalendarPageState._countdown(now, event.ts),
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

class _SentimentPage extends StatelessWidget {
  const _SentimentPage({required this.sentiment});
  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final color = sentiment.label.toSignalColor();
    final isNews = sentiment.headlines.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('MARKET SENTIMENT', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 24)],
          ),
          child: Column(
            children: [
              _SentimentGauge(score: sentiment.score, label: sentiment.label, color: color),
              const SizedBox(height: 20),
              if (isNews) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('BERITA TERBARU', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 10),
                for (final h in sentiment.headlines.take(4)) ...[
                  _NewsItem(headline: h, color: color),
                  const SizedBox(height: 6),
                ],
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sentiment.confidence != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Keyakinan ${(sentiment.confidence! * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(sentiment.source, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SentimentGauge extends StatelessWidget {
  const _SentimentGauge({required this.score, required this.label, required this.color});

  final double score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: (score + 1) / 2,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(2),
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewsItem extends StatelessWidget {
  const _NewsItem({required this.headline, required this.color});
  final String headline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalHistoryCard extends StatelessWidget {
  const _SignalHistoryCard({required this.loading, required this.entries});
  final bool loading;
  final List<Map<String, dynamic>> entries;

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
          const Text('Hasil sinyal harian yang tercatat otomatis vs close hari berikutnya.', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4)),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)))
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
                      child: Text(action, style: TextStyle(color: ac, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    if (cThen != null && cNext != null)
                      Expanded(
                        child: Text(
                          '${cThen.toStringAsFixed(cThen > 100 ? 0 : 5)} â†’ ${cNext.toStringAsFixed(cNext > 100 ? 0 : 5)}',
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
                      child: Text(outcome.toUpperCase(), style: TextStyle(color: oc, fontSize: 10, fontWeight: FontWeight.w800)),
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
                  'Aktifkan ikon lonceng di kanan atas. App mengecek sinyal baru setiap 1 jam di latar belakang (Android) meski app tertutup, lalu memunculkan notifikasi lokal. Tidak perlu langganan Google.',
            ),
            const _GuideSection(
              icon: Icons.flag_rounded,
              title: '4. Alert harga',
              body:
                  'Ketik harga target di bawah sinyal untuk diberi tahu saat harga mencapai target. Satu alert per simbol, otomatis terhapus setelah tersentuh.',
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
                  'Tab Model menampilkan backtest walk-forward (win-rate, drawdown) dan akurasi nyata dari sinyal historis. Model MLP dilatih ulang otomatis. Akurasi >55% dianggap baik, <45% lemah â€” perhatikan tren sebelum mengikuti sinyal.',
            ),
            const _GuideSection(
              icon: Icons.warning_amber_rounded,
              title: 'Disclaimer',
              body:
                  'Sinyal adalah hasil analisis statistik otomatis, bukan saran keuangan. Pasar bisa bergerak melawan prediksi. Trading berisiko tinggi â€” gunakan uang yang siap hilang dan kelola risiko dengan disiplin.',
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
