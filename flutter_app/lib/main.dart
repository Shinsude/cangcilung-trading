import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/push_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.instance.init();
  runApp(const CangcilungApp());
}

class CangcilungApp extends StatelessWidget {
  const CangcilungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cangcilung Trading AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}