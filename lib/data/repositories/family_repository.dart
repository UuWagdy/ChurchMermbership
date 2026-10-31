import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;
import '../database/database_helper.dart';
import '../models/family_models.dart';
import '../models/national_identity.dart';

class FamilyRepository {
  final Database? _database;
  FamilyRepository({Database? database}) : _database = database;
  final _dbHelper = DatabaseHelper();

  Future<List<Family>> getFamilies({String? query}) async {
    final db = _database ?? await _dbHelper.database;
    final families = await db.rawQuery(
      "SELECT o.*, (SELECT COUNT(*) FROM person p WHERE p.osra_id = o.osra_id) AS member_count FROM osra o ORDER BY CASE WHEN o.code IS NULL THEN 1 ELSE 0 END, o.code",
    );
    final term = normalizeSearch(query ?? '');
    final people = term.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query('person');
    final matchingIds = people
        .where(
          (p) => ['person_name', 'mobile', 'rakm_komy'].any(
            (key) => normalizeSearch(p[key]?.toString() ?? '').contains(term),
          ),
        )
        .map((p) => p['osra_id'])
        .toSet();
    return families
        .where(
          (f) =>
              term.isEmpty ||
              ['osra_name', 'phone', 'rakm_komy'].any(
                (key) =>
                    normalizeSearch(f[key]?.toString() ?? '').contains(term),
              ) ||
              matchingIds.contains(f['osra_id']) ||
              normalizeSearch(f['code']?.toString() ?? '').contains(term),
        )
        .map(Family.fromMap)
        .toList();
  }

  Future<Family?> getFamilyById(int id) async {
    final db = _database ?? await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'osra',
      where: 'osra_id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Family.fromMap(maps.first);
    return null;
  }

  Future<int> insertFamily(Family family) async {
    final db = _database ?? await _dbHelper.database;
    return await db.insert('osra', family.toMap());
  }

  Future<int> updateFamily(Family family) async {
    final db = _database ?? await _dbHelper.database;
    return await db.update(
      'osra',
      family.toMap(),
      where: 'osra_id = ?',
      whereArgs: [family.osraId],
    );
  }

  Future<void> deleteFamily(int id) async {
    final db = _database ?? await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM eatraf WHERE person_id IN (
          SELECT person_id FROM person WHERE osra_id = ?
        )
      ''',
        [id],
      );
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
    final db = _database ?? await _dbHelper.database;
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

  Future<List<Map<String, dynamic>>> getFamiliesWithLastVisit(
    List<int> areaIds,
  ) async {
    if (areaIds.isEmpty) return [];
    final db = _database ?? await _dbHelper.database;
    final String sql =
        '''
      SELECT o.osra_id, o.osra_name, o.code, o.dalil_name, s.street_name, a.area_name,
             (SELECT v.date FROM visits v WHERE v.osra_id = o.osra_id ORDER BY v.date DESC, v.visit_id DESC LIMIT 1) as last_visit_date,
             (SELECT v.notes FROM visits v WHERE v.osra_id = o.osra_id ORDER BY v.date DESC, v.visit_id DESC LIMIT 1) as last_visit_notes
      FROM osra o
      LEFT JOIN streets s ON o.street_id = s.street_id
      LEFT JOIN areas a ON o.area_id = a.area_id
      WHERE o.area_id IN (${areaIds.map((_) => '?').join(',')})
      ORDER BY CASE WHEN o.code IS NULL THEN 1 ELSE 0 END, o.code ASC
    ''';
    return await db.rawQuery(sql, areaIds);
  }
}

class PersonRepository {
  final Database? _database;
  PersonRepository({Database? database}) : _database = database;
  final _dbHelper = DatabaseHelper();

  Future<List<Person>> getAllPersons() async {
    final db = _database ?? await _dbHelper.database;
    return (await db.query('person')).map(Person.fromMap).toList();
  }

  Future<List<Person>> getPersonsByFamily(int osraId) async {
    final db = _database ?? await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'person',
      where: 'osra_id = ?',
      whereArgs: [osraId],
    );
    return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
  }

  Future<List<Person>> getPersonsByBirthMonth(int month) async {
    final db = _database ?? await _dbHelper.database;
    final maps = await db.query('person');
    final members = maps.map(Person.fromMap).toList();
    final people = members
        .where((p) => DateTime.tryParse(p.birthDate ?? '')?.month == month)
        .toList();
    final birthdayMembers = <int, List<Person>>{};
    for (final p in people) {
      birthdayMembers.putIfAbsent(p.osraId, () => []).add(p);
    }
    for (final raw in await db.query('osra')) {
      final head = Family.fromMap(raw);
      if (DateTime.tryParse(head.birthDate ?? '')?.month != month) continue;
      final headId = normalizeDigits(head.rakmKomy ?? '');
      final headName = normalizeSearch(head.osraName);
      final alreadyListed = (birthdayMembers[head.osraId] ?? []).any((p) {
        final memberId = normalizeDigits(p.rakmKomy ?? '');
        if (headId.isNotEmpty && memberId.isNotEmpty) {
          return headId == memberId;
        }
        return headName.isNotEmpty &&
            normalizeSearch(p.personName) == headName &&
            p.birthDate == head.birthDate;
      });
      if (alreadyListed) continue;
      // A read-only report entry, not a new persisted member. A null personId
      // preserves the distinction between the head and a member row.
      people.add(
        Person(
          osraId: head.osraId!,
          personName: head.osraName,
          birthDate: head.birthDate,
          age: head.age,
          gender: head.gender,
          governorate: head.governorate,
          rakmKomy: head.rakmKomy,
          mobile: head.phone,
        ),
      );
    }
    people.sort(
      (a, b) => DateTime.parse(
        a.birthDate!,
      ).day.compareTo(DateTime.parse(b.birthDate!).day),
    );
    return people;
  }

  Future<int> insertPerson(Person person) async {
    final db = _database ?? await _dbHelper.database;
    return await db.insert('person', person.toMap());
  }

  Future<int> updatePerson(Person person) async {
    final db = _database ?? await _dbHelper.database;
    return await db.update(
      'person',
      person.toMap(),
      where: 'person_id = ?',
      whereArgs: [person.personId],
    );
  }

  Future<int> deletePerson(int id) async {
    final db = _database ?? await _dbHelper.database;
    return await db.delete('person', where: 'person_id = ?', whereArgs: [id]);
  }

  Future<List<Person>> getPersonsByStage(int stageId) async {
    final db = _database ?? await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'person',
      where: 'stage_id = ?',
      whereArgs: [stageId],
    );
    return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
  }

  Future<int> promotePersonsStage(List<int> personIds, int toStageId) async {
    if (personIds.isEmpty) return 0;
    final db = _database ?? await _dbHelper.database;
    return await db.update(
      'person',
      {'stage_id': toStageId},
      where: "person_id IN (${personIds.map((_) => '?').join(',')})",
      whereArgs: personIds,
    );
  }
}
