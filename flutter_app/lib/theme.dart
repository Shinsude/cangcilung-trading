import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceAlt = Color(0xFF1E293B);
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF2D3A50);
  static const Color green = Color(0xFF00E68A);
  static const Color greenSoft = Color(0xFF0D3D2E);
  static const Color greenGlow = Color(0x4000E68A);
  static const Color red = Color(0xFFFF4D6A);
  static const Color redSoft = Color(0xFF3D101B);
  static const Color redGlow = Color(0x40FF4D6A);
  static const Color amber = Color(0xFFFFB020);
  static const Color amberSoft = Color(0xFF3D2E0D);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF7B8AA5);
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
      titleSpacing: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
