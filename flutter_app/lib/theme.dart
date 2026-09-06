import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF151B29);
  static const Color surfaceAlt = Color(0xFF1D2536);
  static const Color border = Color(0xFF273349);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF8B97A8);
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
        borderRadius: BorderRadius.circular(14),
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