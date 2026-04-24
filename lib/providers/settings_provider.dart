import 'package:flutter/material.dart';
import '../data/repositories/settings_repository.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsRepository _settingsRepo = SettingsRepository();
  bool _isLoading = false;
  
  // Cache of loaded settings
  final Map<String, String> _settingsCache = {};

  bool get isLoading => _isLoading;

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
