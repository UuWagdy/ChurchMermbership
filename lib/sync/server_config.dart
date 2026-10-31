import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _keyEnabled = 'sync_server_enabled';
  static const String _keyBaseUrl = 'sync_server_base_url';

  static bool isServerMode = false;
  static String baseUrl = 'http://127.0.0.1:5060';

  static String normalizeUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return 'http://127.0.0.1:5060';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isServerMode = prefs.getBool(_keyEnabled) ?? false;
    baseUrl = normalizeUrl(prefs.getString(_keyBaseUrl) ?? 'http://127.0.0.1:5060');
  }

  static Future<void> save({required bool enabled, required String url}) async {
    final normalized = normalizeUrl(url);
    isServerMode = enabled;
    baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    await prefs.setString(_keyBaseUrl, normalized);
  }
}
