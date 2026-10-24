// Biometric Service for Dilkash Staff App
// Stores and verifies biometrics preferences and saved credentials.

import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _keyBiometricEnabled = 'dilkash_biometric_enabled';
  static const _keySavedPhone = 'dilkash_saved_phone';
  static const _keySavedStaffCode = 'dilkash_saved_staff_code';
  static const _keySavedPin = 'dilkash_saved_pin';
  static const _keySavedSessionJson = 'dilkash_saved_session_json';

  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyBiometricEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  static Future<void> saveCredentials({
    required String phone,
    required String staffCode,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedPhone, phone);
    await prefs.setString(_keySavedStaffCode, staffCode);
    await prefs.setString(_keySavedPin, pin);
  }

  static Future<Map<String, String>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'phone': prefs.getString(_keySavedPhone) ?? '',
      'staff_code': prefs.getString(_keySavedStaffCode) ?? '',
      'pin': prefs.getString(_keySavedPin) ?? '',
    };
  }

  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedPhone);
    await prefs.remove(_keySavedStaffCode);
    await prefs.remove(_keySavedPin);
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keySavedSessionJson);
  }
}
