import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF121826);
  static const Color surfaceAlt = Color(0xFF1B2333);
  static const Color border = Color(0xFF232F44);
  static const Color green = Color(0xFF2EE6A8);
  static const Color greenSoft = Color(0xFF1B4A3A);
  static const Color red = Color(0xFFF6465D);
  static const Color redSoft = Color(0xFF4A1B26);
  static const Color amber = Color(0xFFF0B90B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF7C8AA5);
  static const Color success = Color(0xFF16C784);
}

const Color _seed = AppColors.blue;

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}

extension SignalColor on String {
  Color toSignalColor() {
    switch (this) {
      case 'BUY':
      case 'STRONG':
      case 'BULLISH':
      case 'UP':
        return AppColors.green;
      case 'SELL':
      case 'BEARISH':
      case 'DOWN':
        return AppColors.red;
      case 'MODERATE':
        return AppColors.amber;
      default:
        return AppColors.amber;
    }
  }
}