import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

export 'package:dilkash_design_system/dilkash_design_system.dart';

class StaffThemeController extends ChangeNotifier {
  StaffThemeController._();
  static final StaffThemeController instance = StaffThemeController._();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    if (isDarkMode) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

/// Dilkash Premium Color System for Staff
class StaffColors {
  // Brand Primary (Dilkash Forest Emerald)
  static const Color primary = DilkashColors.primary500;
  static const Color primaryDark = DilkashColors.primary700;
  static const Color primaryLight = DilkashColors.primary400;
  static const Color primarySoft = DilkashColors.primary50;

  // Brand Secondary & Accents
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF334155);
  static const Color accent = DilkashColors.primary500;
  static const Color accentBright = DilkashColors.primary400;

  // Semantic Status Colors
  static const Color success = DilkashColors.success;
  static const Color successSoft = DilkashColors.successLight;
  static const Color warning = DilkashColors.warning;
  static const Color warningSoft = DilkashColors.warningLight;
  static const Color error = DilkashColors.error;
  static const Color errorSoft = DilkashColors.errorLight;
  static const Color info = DilkashColors.info;
  static const Color infoSoft = DilkashColors.infoLight;

  // Surfaces & Backgrounds (Light Mode)
  static const Color bgLight = DilkashColors.bgLight;
  static const Color cardLight = Colors.white;
  static const Color cardSecondaryLight = Color(0xFFF1F5F9);
  static const Color borderLight = DilkashColors.borderLight;
  static const Color inputLight = DilkashColors.inputLight;
  static const Color textPrimaryLight = DilkashColors.textPrimaryLight;
  static const Color textSecondaryLight = DilkashColors.textSecondaryLight;
  static const Color textMutedLight = DilkashColors.textMutedLight;

  // Surfaces & Backgrounds (Dark Mode)
  static const Color bgDark = DilkashColors.bgDark;
  static const Color cardDark = DilkashColors.surfaceDark;
  static const Color cardSecondaryDark = DilkashColors.surfaceDarkElevated;
  static const Color borderDark = DilkashColors.borderDark;
  static const Color inputDark = DilkashColors.inputDark;
  static const Color textPrimaryDark = DilkashColors.textPrimaryDark;
  static const Color textSecondaryDark = DilkashColors.textSecondaryDark;
  static const Color textMutedDark = DilkashColors.textMutedDark;

  // Dynamic Theme-Aware Getters
  static Color background(bool isDark) => isDark ? bgDark : bgLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color cardSecondary(bool isDark) => isDark ? cardSecondaryDark : cardSecondaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color input(bool isDark) => isDark ? inputDark : inputLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
}

class StaffDesign {
  // Border Radii
  static const double rXs = 8.0;
  static const double rSm = 10.0;
  static const double rMd = 14.0;
  static const double rLg = 18.0;
  static const double rXl = 26.0;

  static BorderRadius get radiusXs => BorderRadius.circular(rXs);
  static BorderRadius get radiusSm => BorderRadius.circular(rSm);
  static BorderRadius get radiusMd => BorderRadius.circular(rMd);
  static BorderRadius get radiusLg => BorderRadius.circular(rLg);
  static BorderRadius get radiusXl => BorderRadius.circular(rXl);
  static BorderRadius get radiusSheet => const BorderRadius.vertical(top: Radius.circular(rXl));

  // Border widths
  static const double borderStandard = 1.0;
  static const double borderThick = 1.5;
}

class StaffTheme {
  StaffTheme._();

  static ThemeData get lightTheme => DilkashTheme.lightTheme;
  static ThemeData get darkTheme => DilkashTheme.darkTheme;
}
