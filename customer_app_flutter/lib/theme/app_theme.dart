import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

export 'package:dilkash_design_system/dilkash_design_system.dart';

/// Uzum Tezkor Signature Visual Palette
class UzumTezkorColors {
  UzumTezkorColors._();

  // Signature Uzum Violet
  static const Color primary = Color(0xFF7000FF);
  static const Color primaryLight = Color(0xFFF3EBFF);
  static const Color primaryDark = Color(0xFF5600CC);

  // Tezkor Fast & Halal Green
  static const Color fastGreen = Color(0xFF00C853);
  static const Color fastGreenLight = Color(0xFFE8F9EE);

  // Rating Star Amber
  static const Color starAmber = Color(0xFFFFB703);
  static const Color starAmberLight = Color(0xFFFFF7E6);

  // Clean modern surfaces (Light Mode)
  static const Color bgLight = Color(0xFFF5F6F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightElevated = Color(0xFFECEEF2);
  static const Color borderLight = Color(0xFFECEEF2);
  static const Color inputLight = Color(0xFFF5F6F8);
  static const Color textPrimaryLight = Color(0xFF18181B);
  static const Color textSecondaryLight = Color(0xFF71717A);

  // Dark mode surfaces
  static const Color bgDark = Color(0xFF101014);
  static const Color surfaceDark = Color(0xFF18181E);
  static const Color surfaceDarkElevated = Color(0xFF22222B);
  static const Color borderDark = Color(0xFF2A2A36);
  static const Color inputDark = Color(0xFF18181E);
  static const Color textPrimaryDark = Color(0xFFF4F4F6);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
}

typedef AppColors = DilkashColors;

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: UzumTezkorColors.primary,
        onPrimary: Colors.white,
        primaryContainer: UzumTezkorColors.primaryLight,
        onPrimaryContainer: UzumTezkorColors.primaryDark,
        secondary: UzumTezkorColors.fastGreen,
        onSecondary: Colors.white,
        surface: UzumTezkorColors.surfaceLight,
        onSurface: UzumTezkorColors.textPrimaryLight,
        error: Color(0xFFDC2626),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: UzumTezkorColors.bgLight,
      cardColor: UzumTezkorColors.surfaceLight,
      dividerColor: UzumTezkorColors.borderLight,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: UzumTezkorColors.textPrimaryLight,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: UzumTezkorColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: UzumTezkorColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UzumTezkorColors.borderLight, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: UzumTezkorColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: UzumTezkorColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: UzumTezkorColors.textSecondaryLight,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: UzumTezkorColors.primary,
        onPrimary: Colors.white,
        primaryContainer: UzumTezkorColors.surfaceDarkElevated,
        onPrimaryContainer: Colors.white,
        secondary: UzumTezkorColors.fastGreen,
        onSecondary: Colors.white,
        surface: UzumTezkorColors.surfaceDark,
        onSurface: UzumTezkorColors.textPrimaryDark,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: UzumTezkorColors.bgDark,
      cardColor: UzumTezkorColors.surfaceDark,
      dividerColor: UzumTezkorColors.borderDark,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: UzumTezkorColors.surfaceDark,
        foregroundColor: UzumTezkorColors.textPrimaryDark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: UzumTezkorColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: UzumTezkorColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UzumTezkorColors.borderDark, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: UzumTezkorColors.surfaceDark,
        elevation: 0,
        indicatorColor: UzumTezkorColors.surfaceDarkElevated,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: UzumTezkorColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: UzumTezkorColors.textSecondaryDark,
          );
        }),
      ),
    );
  }
}
