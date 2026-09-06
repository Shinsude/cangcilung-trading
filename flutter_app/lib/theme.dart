import 'dart:ui';

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
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF475569);
  static const Color glass = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
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

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.borderRadius, this.blur});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur ?? 20, sigmaY: blur ?? 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(borderRadius ?? 20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlowCard extends StatelessWidget {
  const GlowCard({super.key, required this.child, this.padding, this.glowColor, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final gc = glowColor ?? AppColors.green;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? gc.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: gc.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: gc.withValues(alpha: 0.04), blurRadius: 48, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
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
