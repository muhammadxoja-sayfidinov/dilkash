import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  static const String modeLocalPos = 'local_pos';
  static const String modeCloud = 'cloud';

  static const String _cloudUrlKey = 'dilkash_staff_api_base_url';
  static const String _localPosUrlKey = 'dilkash_pos_local_base_url';
  static const String _modeKey = 'dilkash_connection_mode';

  static const String defaultCloudUrl = String.fromEnvironment(
    'DILKASH_API_URL',
    defaultValue: 'https://dilkash-django-production.up.railway.app',
  );
  static const String defaultBaseUrl = defaultCloudUrl;

  static String _cloudBaseUrl = defaultCloudUrl;
  static String _posLocalBaseUrl = '';
  static String _connectionMode = modeLocalPos;

  static String get cloudBaseUrl => _cloudBaseUrl;
  static String get posLocalBaseUrl => _posLocalBaseUrl;
  static String get connectionMode => _connectionMode;
  static bool get isLocalPosMode => _connectionMode == modeLocalPos;
  static bool get hasLocalPos => _posLocalBaseUrl.isNotEmpty;

  static String get baseUrl =>
      isLocalPosMode && _posLocalBaseUrl.isNotEmpty ? _posLocalBaseUrl : _cloudBaseUrl;

  /// Waiter / Login strictly resolves ONLY to Local Wi-Fi POS Hub when in `local_pos` mode.
  /// It NEVER falls back silently to Railway internet for Waiter traffic.
  static String resolveBaseUrl({bool forCourier = false}) {
    if (forCourier) {
      return _cloudBaseUrl;
    }
    if (isLocalPosMode) {
      return _posLocalBaseUrl;
    }
    return _cloudBaseUrl;
  }

  static Future<void> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCloud = prefs.getString(_cloudUrlKey)?.trim();
      if (savedCloud != null && savedCloud.isNotEmpty) {
        _cloudBaseUrl = _normalizeUrl(savedCloud, fallback: defaultCloudUrl);
      }
      final savedLocal = prefs.getString(_localPosUrlKey)?.trim();
      if (savedLocal != null && savedLocal.isNotEmpty) {
        _posLocalBaseUrl = _normalizeUrl(savedLocal);
      }
      final savedMode = prefs.getString(_modeKey)?.trim();
      if (savedMode == modeLocalPos || savedMode == modeCloud) {
        _connectionMode = savedMode!;
      }
    } catch (_) {}
  }

  static Future<String> loadSavedBaseUrl() async {
    await loadAll();
    return baseUrl;
  }

  static Future<void> setLocalPosBaseUrl(String url) async {
    final trimmed = _normalizeUrl(url);
    _posLocalBaseUrl = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (trimmed.isEmpty) {
        await prefs.remove(_localPosUrlKey);
      } else {
        await prefs.setString(_localPosUrlKey, trimmed);
      }
    } catch (_) {}
  }

  static Future<void> setCloudBaseUrl(String url) async {
    final normalized = _normalizeUrl(url, fallback: defaultCloudUrl);
    _cloudBaseUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cloudUrlKey, normalized);
    } catch (_) {}
  }

  static Future<void> setConnectionMode(String mode) async {
    _connectionMode = mode == modeCloud ? modeCloud : modeLocalPos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, _connectionMode);
    } catch (_) {}
  }

  static Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeUrl(url, fallback: defaultCloudUrl);
    if (normalized.contains(':8088') ||
        normalized.startsWith('http://192.168.') ||
        normalized.startsWith('http://10.') ||
        normalized.startsWith('http://172.') ||
        normalized.startsWith('http://127.0.0.1')) {
      await setLocalPosBaseUrl(normalized);
      await setConnectionMode(modeLocalPos);
    } else {
      await setCloudBaseUrl(normalized);
    }
  }

  static Future<void> resetBaseUrl() async {
    _cloudBaseUrl = defaultCloudUrl;
    _posLocalBaseUrl = '';
    _connectionMode = modeLocalPos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cloudUrlKey);
      await prefs.remove(_localPosUrlKey);
      await prefs.remove(_modeKey);
    } catch (_) {}
  }

  static String _normalizeUrl(String url, {String fallback = ''}) {
    var trimmed = url.trim();
    if (trimmed.isNotEmpty &&
        !trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return fallback;
    if ((trimmed.startsWith('http://192.168.') ||
            trimmed.startsWith('http://10.') ||
            trimmed.startsWith('http://172.') ||
            trimmed.startsWith('http://127.0.0.1')) &&
        !RegExp(r':\d+$').hasMatch(trimmed)) {
      trimmed = '$trimmed:8088';
    }
    return trimmed;
  }
}
