import 'package:flutter/material.dart';

/// Dilkash Restaurant Premium Color Tokens
/// Inspired by authentic Uzbek culinary prestige, deep emerald herbs, and saffron warmth.
class DilkashColors {
  DilkashColors._();

  // ==================== BRAND PRIMARY (FOREST EMERALD) ====================
  static const Color primary50 = Color(0xFFE8F5EF);
  static const Color primary100 = Color(0xFFC7E6D8);
  static const Color primary200 = Color(0xFF94CFB7);
  static const Color primary300 = Color(0xFF57B290);
  static const Color primary400 = Color(0xFF10B981);
  static const Color primary500 = Color(0xFF0D6B4E); // Core Brand Primary
  static const Color primary600 = Color(0xFF0A5840);
  static const Color primary700 = Color(0xFF084633);
  static const Color primary800 = Color(0xFF063628);
  static const Color primary900 = Color(0xFF04241B);

  // ==================== ACCENT (SAFFRON & AMBER) ====================
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706); // Core Accent Amber
  static const Color amber700 = Color(0xFFB45309);

  // ==================== LIGHT MODE SURFACES ====================
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightElevated = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderLightSubtle = Color(0xFFF1F5F9);
  static const Color inputLight = Color(0xFFF8FAFC);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // ==================== DARK MODE SURFACES (DEEP PINE SLATE) ====================
  static const Color bgDark = Color(0xFF09100C);
  static const Color surfaceDark = Color(0xFF111D17);
  static const Color surfaceDarkElevated = Color(0xFF182820);
  static const Color borderDark = Color(0xFF1E3529);
  static const Color borderDarkSubtle = Color(0xFF14241C);
  static const Color inputDark = Color(0xFF0D1712);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // ==================== SEMANTIC STATUS COLORS ====================
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF064E3B);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFF78350F);

  static const Color error = Color(0xFFE11D48);
  static const Color errorLight = Color(0xFFFFF1F2);
  static const Color errorDark = Color(0xFF881337);

  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color infoDark = Color(0xFF1E3A8A);

  // ==================== DYNAMIC THEME-AWARE ACCESSORS ====================
  static Color primary(bool isDark) => isDark ? primary400 : primary500;
  static Color background(bool isDark) => isDark ? bgDark : bgLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color surfaceElevated(bool isDark) => isDark ? surfaceDarkElevated : surfaceLightElevated;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color borderSubtle(bool isDark) => isDark ? borderDarkSubtle : borderLightSubtle;
  static Color input(bool isDark) => isDark ? inputDark : inputLight;

  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
}
