import '../database/database_helper.dart';
import '../models/family_models.dart';

class SearchRepository {
  final _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> complexSearch({
    int? areaId,
    int? streetId,
    String? mobile,
    String? birthMonth,
    int? personCount,
    int? socialStatusId,
    int? economicStatusId,
    int? stageId,
    String? job,
    int? ageMin,
    int? ageMax,
    String? name,
    int? healthStatusId,
    int? fatherId,
    int? mostwaId,
    int? karabaId,
  }) async {
    final db = await _dbHelper.database;
    
    // Joint query between Osra and Person to enable all filters
    String query = '''
      SELECT DISTINCT o.* 
      FROM osra o
      LEFT JOIN person p ON o.osra_id = p.osra_id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];

    if (areaId != null) {
      query += ' AND o.area_id = ?';
      args.add(areaId);
    }
    if (streetId != null) {
      query += ' AND o.street_id = ?';
      args.add(streetId);
    }
    if (mobile != null && mobile.isNotEmpty) {
      query += ' AND (o.phone LIKE ? OR p.mobile LIKE ?)';
      args.add('%$mobile%');
      args.add('%$mobile%');
    }
    if (birthMonth != null && birthMonth.isNotEmpty) {
      query += ' AND p.month = ?';
      args.add(birthMonth);
    }
    if (personCount != null) {
      query += ' AND o.number = ?';
      args.add(personCount);
    }
    if (socialStatusId != null) {
      query += ' AND o.hala_egtimaia_id = ?';
      args.add(socialStatusId);
    }
    if (economicStatusId != null) {
      query += ' AND o.e_s_id = ?';
      args.add(economicStatusId);
    }
    if (stageId != null) {
      query += ' AND p.stage_id = ?';
      args.add(stageId);
    }
    if (job != null && job.isNotEmpty) {
      query += ' AND p.wazefa LIKE ?';
      args.add('%$job%');
    }
    if (name != null && name.isNotEmpty) {
      query += ' AND (o.osra_name LIKE ? OR p.person_name LIKE ?)';
      args.add('%$name%');
      args.add('%$name%');
    }
    if (healthStatusId != null) {
      query += ' AND p.hala_sehia_id = ?';
      args.add(healthStatusId);
    }
    if (fatherId != null) {
      query += ' AND p.father_id = ?';
      args.add(fatherId);
    }
    if (mostwaId != null) {
      query += ' AND p.mostwa_id = ?';
      args.add(mostwaId);
    }
    if (karabaId != null) {
      query += ' AND p.karaba_id = ?';
      args.add(karabaId);
    }

    // Age filtering is tricky since it's stored as String in original db, 
    // but in SQLite we can try to cast or use the birth_date
    if (ageMin != null || ageMax != null) {
      // Simple approximation: Year difference
      if (ageMin != null) {
        query += " AND (CAST(strftime('%Y', 'now') AS INTEGER) - CAST(strftime('%Y', p.birth_date) AS INTEGER)) >= ?";
        args.add(ageMin);
      }
      if (ageMax != null) {
        query += " AND (CAST(strftime('%Y', 'now') AS INTEGER) - CAST(strftime('%Y', p.birth_date) AS INTEGER)) <= ?";
        args.add(ageMax);
      }
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  Future<List<Map<String, dynamic>>> searchPersons({
    String? name,
    String? nationalId,
    String? mobile,
    String? job,
    int? areaId,
    int? streetId,
    int? socialStatusId,
    int? economicStatusId,
    int? stageId,
    int? healthStatusId,
    int? mostwaId,
    int? karabaId,
  }) async {
    final db = await _dbHelper.database;
    
    String query = '''
      SELECT p.* 
      FROM person p
      LEFT JOIN osra o ON p.osra_id = o.osra_id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];

    if (name != null && name.isNotEmpty) {
      query += ' AND p.person_name LIKE ?';
      args.add('%$name%');
    }
    if (nationalId != null && nationalId.isNotEmpty) {
      query += ' AND p.rakm_komy LIKE ?';
      args.add('%$nationalId%');
    }
    if (mobile != null && mobile.isNotEmpty) {
      query += ' AND p.mobile LIKE ?';
      args.add('%$mobile%');
    }
    if (job != null && job.isNotEmpty) {
      query += ' AND p.wazefa LIKE ?';
      args.add('%$job%');
    }
    if (areaId != null) {
      query += ' AND o.area_id = ?';
      args.add(areaId);
    }
    if (streetId != null) {
      query += ' AND o.street_id = ?';
      args.add(streetId);
    }
    if (socialStatusId != null) {
      // Searching by Person's social status, fallback to Osra if needed
      query += ' AND p.hala_egtimaia_id = ?';
      args.add(socialStatusId);
    }
    if (economicStatusId != null) {
      // Economic status belongs to Osra
      query += ' AND o.e_s_id = ?';
      args.add(economicStatusId);
    }
    if (stageId != null) {
      query += ' AND p.stage_id = ?';
      args.add(stageId);
    }
    if (healthStatusId != null) {
      query += ' AND p.hala_sehia_id = ?';
      args.add(healthStatusId);
    }
    if (mostwaId != null) {
      query += ' AND p.mostwa_id = ?';
      args.add(mostwaId);
    }
    if (karabaId != null) {
      query += ' AND p.karaba_id = ?';
      args.add(karabaId);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }
}
