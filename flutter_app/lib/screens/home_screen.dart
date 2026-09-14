import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

part 'home_screen_parts/nav.dart';
part 'home_screen_parts/shared.dart';
part 'home_screen_parts/signal.dart';
part 'home_screen_parts/indicators.dart';
part 'home_screen_parts/model.dart';
part 'home_screen_parts/calendar.dart';
part 'home_screen_parts/sentiment.dart';
part 'home_screen_parts/extras.dart';

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
  bool _warmed = false;
  bool _notifOn = false;
  bool _minimal = false;
  Timer? _signalWatcher;
  final Map<String, double> _alerts = {};
  final Map<String, List<double>> _confHistory = {};
  List<Map<String, dynamic>> _history = const [];
  bool _historyLoading = false;
  MorningDigest? _digest;
  bool _digestLoaded = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _load();
    _initNotifPref();
    _initMinimalPref();
    _loadAlerts();
    _loadHistory(_selected);
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

  Future<void> _loadHistory(String symbol) async {
    setState(() {
      _historyLoading = true;
      _history = const [];
    });
    try {
      final hist = await _api.fetchHistory(symbol, limit: 15);
      if (!mounted) return;
      setState(() {
        _history = hist;
        _historyLoading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _loadDigest() async {
    if (_digestLoaded) return;
    final d = await _api.fetchDigest();
    if (d == null || !mounted) return;
    _digestLoaded = true;
    setState(() => _digest = d);
    if (_notifOn && !kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final seenKey = 'digest_seen_${d.date}';
        final seen = prefs.getBool(seenKey) ?? false;
        if (!seen) {
          await prefs.setBool(seenKey, true);
          unawaited(NotificationService.instance.showMorningDigest(d.date, d.text));
        }
      } catch (_) {}
    }
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
    unawaited(_registerServerAlert(symbol, target));
  }

  Future<void> _registerServerAlert(String symbol, double target) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('device_id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = DateTime.now().microsecondsSinceEpoch.toString();
        await prefs.setString('device_id', deviceId);
      }
      final reg = await _api.registerAlert(deviceId, symbol, target);
      if (reg != null && mounted) {
        final id = reg['id'] as String?;
        if (id != null) await prefs.setString('alert_id_$symbol', id);
      }
    } catch (_) {}
  }

  Future<void> _clearAlert(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alert_$symbol');
    final serverId = prefs.getString('alert_id_$symbol');
    if (serverId != null && serverId.isNotEmpty) {
      await prefs.remove('alert_id_$symbol');
      if (!kIsWeb) unawaited(_api.deleteAlert(serverId));
    }
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
      final trig = await _api.fetchTriggeredAlerts();
      for (final t in trig) {
        final sym = (t['symbol'] as String?)?.toUpperCase() ?? '';
        final target = (t['target'] as num?)?.toDouble();
        final price = (t['price'] as num?)?.toDouble();
        if (sym.isEmpty || target == null || price == null) continue;
        await prefs.remove('alert_$sym');
        if (mounted) {
          setState(() => _alerts.remove(sym));
          unawaited(NotificationService.instance.showPriceAlert(sym, target, price));
        }
      }
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

  Future<void> _warmOthers() async {
    if (_warmed) return;
    _warmed = true;
    for (final s in _symbols) {
      if (s == _selected) continue;
      try {
        await _api.fetchSignal(s, useCache: false);
      } catch (_) {}
    }
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
      unawaited(_warmOthers());
      unawaited(_loadDigest());
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
    _loadHistory(s);
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
          onChanged: (i) {
            setState(() => _tab = i);
            if (i == 4 && _model == null && !_modelLoading) {
              unawaited(_loadModel());
            }
          },
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
          history: _history,
          historyLoading: _historyLoading,
          digest: _digest,
          onSelectSymbol: _selectSymbol,
        ),
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
