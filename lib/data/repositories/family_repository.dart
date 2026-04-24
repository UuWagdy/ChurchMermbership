import '../database/database_helper.dart';
import '../models/family_models.dart';

class FamilyRepository {
  final _dbHelper = DatabaseHelper();

  Future<List<Family>> getFamilies({String? query}) async {
    final db = await _dbHelper.database;
    final String sql = '''
      SELECT o.*, COUNT(p.person_id) as member_count
      FROM osra o
      LEFT JOIN person p ON o.osra_id = p.osra_id
      ${query != null && query.isNotEmpty ? "WHERE o.osra_name LIKE '%$query%'" : ""}
      GROUP BY o.osra_id
      ORDER BY o.osra_id DESC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql);
    return List.generate(maps.length, (i) => Family.fromMap(maps[i]));
  }

  Future<Family?> getFamilyById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'osra',
      where: 'osra_id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Family.fromMap(maps.first);
    return null;
  }

  Future<int> insertFamily(Family family) async {
    final db = await _dbHelper.database;
    return await db.insert('osra', family.toMap());
  }

  Future<int> updateFamily(Family family) async {
    final db = await _dbHelper.database;
    return await db.update(
      'osra',
      family.toMap(),
      where: 'osra_id = ?',
      whereArgs: [family.osraId],
    );
  }

  Future<void> deleteFamily(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawDelete('''
        DELETE FROM eatraf WHERE person_id IN (
          SELECT person_id FROM person WHERE osra_id = ?
        )
      ''', [id]);
      await txn.delete('person', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('visits', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('monasba', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('count_aid', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('count_2', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('masrofat', where: 'osra_id = ?', whereArgs: [id]);
      await txn.delete('osra', where: 'osra_id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getSummaryReport() async {
    final db = await _dbHelper.database;
    // Get count of families per area
    final String query = '''
      SELECT a.area_name, COUNT(o.osra_id) as family_count, SUM(o.number) as person_count
      FROM areas a
      LEFT JOIN osra o ON o.area_id = a.area_id
      GROUP BY a.area_name
      ORDER BY family_count DESC
    ''';
    return await db.rawQuery(query);
  }
}

class PersonRepository {
  final _dbHelper = DatabaseHelper();

  Future<List<Person>> getPersonsByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'person',
      where: 'osra_id = ?',
      whereArgs: [osraId],
    );
    return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
  }

  Future<List<Person>> getPersonsByBirthMonth(int month) async {
    final db = await _dbHelper.database;
    final formattedMonth = month.toString().padLeft(2, '0');
    final List<Map<String, dynamic>> maps = await db.query(
      'person',
      where: "strftime('%m', birth_date) = ? OR birth_date LIKE ?",
      whereArgs: [formattedMonth, '%-$formattedMonth-%'],
    );
    return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
  }

  Future<int> insertPerson(Person person) async {
    final db = await _dbHelper.database;
    return await db.insert('person', person.toMap());
  }

  Future<int> updatePerson(Person person) async {
    final db = await _dbHelper.database;
    return await db.update(
      'person',
      person.toMap(),
      where: 'person_id = ?',
      whereArgs: [person.personId],
    );
  }

  Future<int> deletePerson(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('person', where: 'person_id = ?', whereArgs: [id]);
  }
}
