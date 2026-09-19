import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/push_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CangcilungApp());
  unawaited(PushService.instance.init());
}

class CangcilungApp extends StatelessWidget {
  const CangcilungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cangcilung Trading AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.4,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}