import '../database/database_helper.dart';
import '../models/lookup_models.dart';

class LookupRepository {
  final _dbHelper = DatabaseHelper();

  // Areas
  Future<List<Area>> getAreas() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('areas');
    return List.generate(maps.length, (i) => Area.fromMap(maps[i]));
  }

  Future<int> insertArea(Area area) async {
    final db = await _dbHelper.database;
    return await db.insert('areas', area.toMap());
  }

  Future<int> updateArea(Area area) async {
    final db = await _dbHelper.database;
    return await db.update(
      'areas', 
      area.toMap(),
      where: 'area_id = ?',
      whereArgs: [area.areaId],
    );
  }

  Future<int> deleteArea(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('areas', where: 'area_id = ?', whereArgs: [id]);
  }

  // Streets
  Future<List<Street>> getStreets(int areaId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'streets',
      where: 'area_id = ?',
      whereArgs: [areaId],
    );
    return List.generate(maps.length, (i) => Street.fromMap(maps[i]));
  }

  Future<int> insertStreet(Street street) async {
    final db = await _dbHelper.database;
    return await db.insert('streets', street.toMap());
  }

  Future<int> updateStreet(Street street) async {
    final db = await _dbHelper.database;
    return await db.update(
      'streets', 
      street.toMap(),
      where: 'street_id = ?',
      whereArgs: [street.streetId],
    );
  }

  Future<int> deleteStreet(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('streets', where: 'street_id = ?', whereArgs: [id]);
  }

  // Fathers (Priests)
  Future<List<Father>> getFathers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('fathers');
    return List.generate(maps.length, (i) => Father.fromMap(maps[i]));
  }

  Future<int> insertFather(Father father) async {
    final db = await _dbHelper.database;
    return await db.insert('fathers', father.toMap());
  }

  // Generic lookup for tables with id and name only
  Future<List<Map<String, dynamic>>> getLookupItems(String tableName) async {
    final db = await _dbHelper.database;
    return await db.query(tableName);
  }

  Future<int> insertLookupItem(String tableName, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.insert(tableName, data);
  }

  Future<int> deleteLookupItem(String tableName, String idColumn, int id) async {
    final db = await _dbHelper.database;
    return await db.delete(tableName, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<int> updateLookupItem(String tableName, String idColumn, int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.update(
      tableName,
      data,
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  // Stages
  Future<List<Map<String, dynamic>>> getStages() => getLookupItems('stage');
  
  // Custom queries from original C# for specific lookups
  Future<List<Map<String, dynamic>>> getKaraba() => getLookupItems('karaba');
  Future<List<Map<String, dynamic>>> getHalaEgtimaia() => getLookupItems('hala_egtimaia');
  Future<List<Map<String, dynamic>>> getHalaSehia() => getLookupItems('hala_sehia');
  Future<List<Map<String, dynamic>>> getEconomicStatus() => getLookupItems('e_s');
  Future<List<Map<String, dynamic>>> getEducationLevels() => getLookupItems('mostwa');
  Future<List<Map<String, dynamic>>> getServices() => getLookupItems('khdma');
}
