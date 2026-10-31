import 'package:flutter/material.dart';
import '../data/repositories/settings_repository.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository _settingsRepo = SettingsRepository();
  bool _isLoading = false;

  // Cache of loaded settings
  final Map<String, String> _settingsCache = {};

  String _churchName = 'كنيسة الشهيدين العظيمين بطرس وبولس';
  String _serviceName = 'Church Membership - العضوية الكنسية';
  ThemeMode _themeMode = ThemeMode.light;
  Color _primaryColor = const Color(0xFF1A237E);

  SettingsProvider() {
    loadSettings();
  }

  bool get isLoading => _isLoading;
  String get churchName => _churchName;
  String get serviceName => _serviceName;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Utility to parse Hex string into Color
  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    var hex = hexString.replaceAll('#', '').replaceAll('0x', '').trim();
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) {
        return Color(val);
      }
    }
    return null;
  }

  /// Convert a Color to Hex string (#RRGGBB)
  static String colorToHex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> loadSettings() async {
    try {
      final all = await _settingsRepo.getAllSettings();
      _settingsCache
        ..clear()
        ..addAll(all);
      _churchName =
          all['church_name'] ??
          all['churchName'] ??
          'كنيسة الشهيدين العظيمين بطرس وبولس';
      _serviceName = 'Church Membership - العضوية الكنسية';
      final modeStr = all['theme_mode'] ?? all['themeMode'];
      if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.light;
      }

      final colorStr = all['primary_color'] ?? all['primaryColor'];
      if (colorStr != null && colorStr.isNotEmpty) {
        final parsed = parseHexColor(colorStr);
        if (parsed != null) {
          _primaryColor = parsed;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Toggle between light and dark modes and persist the preference
  Future<void> toggleThemeMode() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    await saveSetting('theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  /// Explicitly set the theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    if (mode == ThemeMode.system) modeStr = 'system';
    await saveSetting('theme_mode', modeStr);
    notifyListeners();
  }

  /// Set and persist the custom primary accent color
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await saveSetting('primary_color', colorToHex(color));
    notifyListeners();
  }

  Future<void> refreshSilently() => loadSettings();

  /// Retrieves a setting value. If it's not cached, it fetches it from the DB.
  Future<String?> getSetting(String key) async {
    if (_settingsCache.containsKey(key)) {
      return _settingsCache[key];
    }

    _isLoading = true;
    notifyListeners();

    try {
      final value = await _settingsRepo.getSetting(key);
      if (value != null) {
        _settingsCache[key] = value;
      }
      _isLoading = false;
      notifyListeners();
      return value;
    } catch (e) {
      debugPrint('Error getting setting $key: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Saves or updates a setting value in the DB and cache.
  Future<void> saveSetting(String key, String value) async {
    try {
      await _settingsRepo.saveSetting(key, value);
      _settingsCache[key] = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  /// Deletes a setting from the DB and cache.
  Future<void> deleteSetting(String key) async {
    try {
      await _settingsRepo.deleteSetting(key);
      _settingsCache.remove(key);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting setting $key: $e');
    }
  }
}
