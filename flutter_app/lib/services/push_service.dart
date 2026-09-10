import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Layanan notifikasi latar belakang berbasis WorkManager.
///
/// Tanpa Firebase/Google. App membuka sendiri jendela latar belakang periodik
/// yang mengecek sinyal terbaru (1 jam sekali) dan memunculkan notifikasi lokal
/// bila ada sinyal BUY/SELL baru. Berjalan walaupun app di background/tertutup
/// (WorkManager dijadwalkan oleh OS Android).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const String _task = 'cangcilung.signalCheck';

  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        'checkSignals',
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }
}

const String _api = 'https://cangcilung-trading-api.vercel.app';
const List<String> _signalSymbols = ['XAUUSD', 'NASDAQ', 'AUDUSD'];

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != 'checkSignals') return true;
    try {
      await _checkSignalsInBackground();
    } catch (_) {}
    return true;
  });
}

/// Logika yang sama dengan _checkStrongSignals di home_screen, dijalankan
/// di isolate latar belakang tanpa UI.
Future<void> _checkSignalsInBackground() async {
  final prefs = await SharedPreferences.getInstance();
  final plugin = FlutterLocalNotificationsPlugin();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await plugin.initialize(const InitializationSettings(android: android, iOS: ios));

  for (final symbol in _signalSymbols) {
    try {
      final resp = await http
          .get(Uri.parse('$_api/signal/$symbol'))
          .timeout(const Duration(seconds: 40));
      if (resp.statusCode != 200) continue;
      final body = resp.body;
      final actionM = RegExp(r'"action"\s*:\s*"([^"]+)"').firstMatch(body);
      final strengthM = RegExp(r'"strength"\s*:\s*"([^"]+)"').firstMatch(body);
      final action = actionM?.group(1) ?? 'HOLD';
      final strength = strengthM?.group(1) ?? '';
      if (action == 'HOLD') continue;

      final sig = '$action|$strength';
      final last = prefs.getString('last_sig_$symbol') ?? '';
      if (sig == last) continue;

      await prefs.setString('last_sig_$symbol', sig);
      await plugin.show(
        symbol.hashCode,
        '$symbol: $action $strength',
        'Sinyal $action ($strength) terdeteksi untuk $symbol. Buka aplikasi untuk detail indikator.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'signals',
            'Sinyal Trading',
            channelDescription: 'Notifikasi saat sinyal BUY/SELL baru muncul',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // lewati simbol yang gagal; lanjut simbol berikutnya
    }
  }
}