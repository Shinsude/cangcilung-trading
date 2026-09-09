import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

/// Layanan push notifikasi via Firebase Cloud Messaging.
///
/// Hanya aktif di Android (device). Di web atau bila Firebase gagal dimuat,
/// aplikasi tetap memakai notifikasi lokal yang sudah ada (PollingService).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  FlutterLocalNotificationsPlugin? _local;

  bool get ready => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(options: defaultFirebaseOptions());
      final opts = defaultFirebaseOptions();
      if (opts != null && opts.apiKey.isEmpty) {
        // Firebase web config belum diset; nonaktifkan.
        return;
      }
      final messaging = FirebaseMessaging.instance;

      // Izin notifikasi (Android 13+)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Subscribe ke topic sinyal; backend cukup kirim ke topic (ramah serverless).
      await messaging.subscribeToTopic('signals');

      _setupListeners(messaging);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void _setupListeners(FirebaseMessaging messaging) {
    // Pesan saat aplikasi terbuka (foreground) -> tampilkan via local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocal(message);
    });

    // Pesan saat aplikasi dibuka dari notifikasi
    FirebaseMessaging.onMessageOpenedApp.listen((message) {});
  }

  Future<void> _showLocal(RemoteMessage message) async {
    try {
      _local ??= FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local!.initialize(const InitializationSettings(android: android));
      final notif = message.notification;
      if (notif == null) return;
      await _local!.show(
        message.messageId.hashCode,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'signals',
            'Sinyal Trading',
            channelDescription: 'Notifikasi sinyal & alert harga',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}
