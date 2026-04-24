import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SettingsRepository {
  final _dbHelper = DatabaseHelper();

  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['setting_value'] as String?;
    }
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'settings',
      {'setting_key': key, 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await _dbHelper.database;
    await db.delete(
      'settings',
      where: 'setting_key = ?',
      whereArgs: [key],
    );
  }
}
