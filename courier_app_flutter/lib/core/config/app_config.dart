import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  static const String _baseUrlKey = 'dilkash_staff_api_base_url';
  static const String defaultBaseUrl = String.fromEnvironment(
    'DILKASH_API_URL',
    defaultValue: 'https://dilkash-django-production.up.railway.app',
  );

  static String _currentBaseUrl = defaultBaseUrl;
  static String get baseUrl => _currentBaseUrl;

  static Future<String> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_baseUrlKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        _currentBaseUrl = _normalizeUrl(saved);
      }
    } catch (_) {}
    return _currentBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeUrl(url);
    _currentBaseUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlKey, normalized);
    } catch (_) {}
  }

  static Future<void> resetBaseUrl() async {
    _currentBaseUrl = defaultBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_baseUrlKey);
    } catch (_) {}
  }

  static String _normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? defaultBaseUrl : trimmed;
  }
}
