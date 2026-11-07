import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'radii.dart';

/// Dilkash Restaurant Unified ThemeData
class DilkashTheme {
  DilkashTheme._();

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: DilkashColors.primary500,
      onPrimary: Colors.white,
      primaryContainer: DilkashColors.primary50,
      onPrimaryContainer: DilkashColors.primary700,
      secondary: DilkashColors.amber600,
      onSecondary: Colors.white,
      secondaryContainer: DilkashColors.amber50,
      onSecondaryContainer: DilkashColors.amber700,
      surface: DilkashColors.surfaceLight,
      onSurface: DilkashColors.textPrimaryLight,
      error: DilkashColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DilkashColors.bgLight,
      cardColor: DilkashColors.surfaceLight,
      dividerColor: DilkashColors.borderLight,
      textTheme: DilkashTypography.textTheme(false),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: DilkashColors.textPrimaryLight,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: DilkashColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: DilkashColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DilkashRadii.radiusLg,
          side: const BorderSide(color: DilkashColors.borderLight, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: DilkashColors.primary50,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DilkashColors.primary500,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: DilkashColors.textSecondaryLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: DilkashColors.primary500, size: 24);
          }
          return const IconThemeData(
              color: DilkashColors.textSecondaryLight, size: 24);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DilkashColors.inputLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: DilkashColors.textMutedLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.borderLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.primary500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide: const BorderSide(color: DilkashColors.error, width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DilkashColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: DilkashRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DilkashColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: DilkashRadii.radiusLg,
          side: const BorderSide(color: DilkashColors.borderLight, width: 1.0),
        ),
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: DilkashColors.primary400,
      onPrimary: DilkashColors.bgDark,
      primaryContainer: DilkashColors.surfaceDarkElevated,
      onPrimaryContainer: DilkashColors.primary100,
      secondary: DilkashColors.amber500,
      onSecondary: Colors.black,
      secondaryContainer: DilkashColors.amber700,
      onSecondaryContainer: DilkashColors.amber100,
      surface: DilkashColors.surfaceDark,
      onSurface: DilkashColors.textPrimaryDark,
      error: DilkashColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DilkashColors.bgDark,
      cardColor: DilkashColors.surfaceDark,
      dividerColor: DilkashColors.borderDark,
      textTheme: DilkashTypography.textTheme(true),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: DilkashColors.surfaceDark,
        foregroundColor: DilkashColors.textPrimaryDark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: DilkashColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: DilkashColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DilkashRadii.radiusLg,
          side: const BorderSide(color: DilkashColors.borderDark, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DilkashColors.surfaceDark,
        elevation: 0,
        indicatorColor: const Color(0xFF162E23),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DilkashColors.primary400,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: DilkashColors.textSecondaryDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: DilkashColors.primary400, size: 24);
          }
          return const IconThemeData(
              color: DilkashColors.textSecondaryDark, size: 24);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DilkashColors.inputDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: DilkashColors.textMutedDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.borderDark, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.borderDark, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide:
              const BorderSide(color: DilkashColors.primary400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DilkashRadii.radiusSm,
          borderSide: const BorderSide(color: DilkashColors.error, width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DilkashColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: DilkashRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DilkashColors.surfaceDarkElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: DilkashRadii.radiusLg,
          side: const BorderSide(color: DilkashColors.borderDark, width: 1.0),
        ),
      ),
    );
  }
}
