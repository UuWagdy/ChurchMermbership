import '../database/database_helper.dart';
import '../models/tracking_models.dart';

class TrackingRepository {
  final _dbHelper = DatabaseHelper();

  // Confessions (Eatraf)
  Future<List<Confession>> getConfessionsByPerson(int personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'eatraf',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Confession.fromMap(maps[i]));
  }

  Future<int> insertConfession(Confession confession) async {
    final db = await _dbHelper.database;
    return await db.insert('eatraf', confession.toMap());
  }

  Future<int> updateConfession(Confession confession) async {
    final db = await _dbHelper.database;
    return await db.update(
      'eatraf',
      confession.toMap(),
      where: 'eatraf_id = ?',
      whereArgs: [confession.eatrafId],
    );
  }

  Future<int> deleteConfession(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('eatraf', where: 'eatraf_id = ?', whereArgs: [id]);
  }

  // Visits (Visitor)
  Future<List<Visit>> getVisitsByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'visits',
      where: 'osra_id = ?',
      whereArgs: [osraId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Visit.fromMap(maps[i]));
  }

  Future<int> insertVisit(Visit visit) async {
    final db = await _dbHelper.database;
    return await db.insert('visits', visit.toMap());
  }

  Future<int> deleteVisit(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('visits', where: 'visit_id = ?', whereArgs: [id]);
  }

  // Occasions (Monasba)
  Future<List<Occasion>> getOccasionsByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monasba',
      where: 'osra_id = ?',
      whereArgs: [osraId],
    );
    return List.generate(maps.length, (i) => Occasion.fromMap(maps[i]));
  }

  Future<int> insertOccasion(Occasion occasion) async {
    final db = await _dbHelper.database;
    return await db.insert('monasba', occasion.toMap());
  }

  Future<int> updateOccasion(Occasion occasion) async {
    final db = await _dbHelper.database;
    return await db.update(
      'monasba', 
      occasion.toMap(),
      where: 'monasba_id = ?',
      whereArgs: [occasion.monasbaId],
    );
  }

  Future<int> deleteOccasion(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('monasba', where: 'monasba_id = ?', whereArgs: [id]);
  }
}
