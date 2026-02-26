import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color background = Color(0xFF070B14);
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color textMono = Color(0xFF7EB8FF);

  static const Color online = Color(0xFF00FFA3);
  static const Color onlineGlow = Color(0x5500FFA3);
  static const Color slow = Color(0xFFFFB800);
  static const Color slowGlow = Color(0x55FFB800);
  static const Color offline = Color(0xFFFF3B5C);
  static const Color offlineGlow = Color(0x55FF3B5C);
  static const Color unknown = Color(0xFF4A6080);
  static const Color unknownGlow = Color(0x334A6080);

  static const String fontMono = 'monospace';

  static BoxDecoration glassCard({double borderRadius = 20}) => BoxDecoration(
        color: glassWhite,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0D1525),
          primary: online,
        ),
        useMaterial3: true,
      );
}
