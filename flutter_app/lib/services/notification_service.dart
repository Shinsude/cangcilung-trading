import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  Future<bool> enabledOnDevice() async {
    if (kIsWeb) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    return true;
  }

  Future<void> showStrongSignal(String symbol, String action, String strength) async {
    if (kIsWeb) return;
    await _init();
    try {
      await _plugin.show(
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
    } catch (_) {}
  }
}