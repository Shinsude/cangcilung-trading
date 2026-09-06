import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
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