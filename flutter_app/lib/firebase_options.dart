import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Konfigurasi Firebase.
///
/// Di Android, firebase_core menginisialisasi otomatis dari `google-services.json`
/// (plugin com.google.gms.google-services), jadi tidak perlu FirebaseOptions di sini.
/// Nilai non-null untuk platform lain (mis. web) bisa diisi setelah project Firebase
/// aktif; sampai itu tersedia, platform tersebut tidak memakai Firebase (fallback
/// ke notifikasi lokal).
FirebaseOptions? defaultFirebaseOptions() {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID'),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    );
  }
  return null;
}
