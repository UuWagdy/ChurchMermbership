import '../database/database_helper.dart';
import '../models/family_models.dart';

class SearchRepository {
  final _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> complexSearch({
    List<int>? areaIds,
    int? streetId,
    String? mobile,
    List<String>? birthMonths,
    int? personCount,
    List<int>? socialStatusIds,
    List<int>? economicStatusIds,
    List<int>? stageIds,
    String? job,
    int? ageMin,
    int? ageMax,
    String? name,
    List<int>? healthStatusIds,
    int? fatherId,
    List<int>? mostwaIds,
    List<int>? karabaIds,
    String? nidGov,
    String? nidGender,
    int? nidAgeMin,
    int? nidAgeMax,
    String? nidBirthDateMin,
    String? nidBirthDateMax,
  }) async {
    final db = await _dbHelper.database;
    
    // Joint query between Osra and Person to enable all filters
    String query = '''
      SELECT DISTINCT o.*, (SELECT COUNT(*) FROM person p2 WHERE p2.osra_id = o.osra_id) as member_count
      FROM osra o
      LEFT JOIN person p ON o.osra_id = p.osra_id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];

    if (areaIds != null && areaIds.isNotEmpty) {
      query += ' AND o.area_id IN (${areaIds.map((_) => '?').join(',')})';
      args.addAll(areaIds);
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
    if (birthMonths != null && birthMonths.isNotEmpty) {
      query += ' AND p.month IN (${birthMonths.map((_) => '?').join(',')})';
      args.addAll(birthMonths);
    }
    if (personCount != null) {
      query += ' AND o.number = ?';
      args.add(personCount);
    }
    if (socialStatusIds != null && socialStatusIds.isNotEmpty) {
      query += ' AND o.hala_egtimaia_id IN (${socialStatusIds.map((_) => '?').join(',')})';
      args.addAll(socialStatusIds);
    }
    if (economicStatusIds != null && economicStatusIds.isNotEmpty) {
      query += ' AND o.e_s_id IN (${economicStatusIds.map((_) => '?').join(',')})';
      args.addAll(economicStatusIds);
    }
    if (stageIds != null && stageIds.isNotEmpty) {
      query += ' AND p.stage_id IN (${stageIds.map((_) => '?').join(',')})';
      args.addAll(stageIds);
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
    if (healthStatusIds != null && healthStatusIds.isNotEmpty) {
      query += ' AND p.hala_sehia_id IN (${healthStatusIds.map((_) => '?').join(',')})';
      args.addAll(healthStatusIds);
    }
    if (fatherId != null) {
      query += ' AND p.father_id = ?';
      args.add(fatherId);
    }
    if (mostwaIds != null && mostwaIds.isNotEmpty) {
      query += ' AND p.mostwa_id IN (${mostwaIds.map((_) => '?').join(',')})';
      args.addAll(mostwaIds);
    }
    if (karabaIds != null && karabaIds.isNotEmpty) {
      query += ' AND p.karaba_id IN (${karabaIds.map((_) => '?').join(',')})';
      args.addAll(karabaIds);
    }

    // Filter on National ID Governorate
    if (nidGov != null && nidGov.isNotEmpty) {
      query += ''' AND (
        (p.rakm_komy IS NOT NULL AND LENGTH(p.rakm_komy) = 14 AND SUBSTR(p.rakm_komy, 8, 2) = ?)
        OR
        (o.rakm_komy IS NOT NULL AND LENGTH(o.rakm_komy) = 14 AND SUBSTR(o.rakm_komy, 8, 2) = ?)
      )''';
      args.add(nidGov);
      args.add(nidGov);
    }
    
    // Filter on National ID Gender
    if (nidGender != null && nidGender.isNotEmpty) {
      if (nidGender == 'ذكر') {
        query += ''' AND (
          (p.rakm_komy IS NOT NULL AND LENGTH(p.rakm_komy) = 14 AND CAST(SUBSTR(p.rakm_komy, 13, 1) AS INTEGER) % 2 = 1)
          OR
          (o.rakm_komy IS NOT NULL AND LENGTH(o.rakm_komy) = 14 AND CAST(SUBSTR(o.rakm_komy, 13, 1) AS INTEGER) % 2 = 1)
        )''';
      } else if (nidGender == 'أنثى') {
        query += ''' AND (
          (p.rakm_komy IS NOT NULL AND LENGTH(p.rakm_komy) = 14 AND CAST(SUBSTR(p.rakm_komy, 13, 1) AS INTEGER) % 2 = 0)
          OR
          (o.rakm_komy IS NOT NULL AND LENGTH(o.rakm_komy) = 14 AND CAST(SUBSTR(o.rakm_komy, 13, 1) AS INTEGER) % 2 = 0)
        )''';
      }
    }

    // Filter on National ID Age
    if (nidAgeMin != null || nidAgeMax != null) {
      final pAgeExpr = "CAST((strftime('%Y%m%d', 'now') - CAST(CASE SUBSTR(p.rakm_komy, 1, 1) WHEN '3' THEN '20' ELSE '19' END || SUBSTR(p.rakm_komy, 2, 6) AS INTEGER)) / 10000 AS INTEGER)";
      final oAgeExpr = "CAST((strftime('%Y%m%d', 'now') - CAST(CASE SUBSTR(o.rakm_komy, 1, 1) WHEN '3' THEN '20' ELSE '19' END || SUBSTR(o.rakm_komy, 2, 6) AS INTEGER)) / 10000 AS INTEGER)";
      
      query += ' AND (';
      List<String> conditions = [];
      List<dynamic> pArgs = [];
      List<dynamic> oArgs = [];
      
      String pCond = '(p.rakm_komy IS NOT NULL AND LENGTH(p.rakm_komy) = 14';
      if (nidAgeMin != null) {
        pCond += ' AND $pAgeExpr >= ?';
        pArgs.add(nidAgeMin);
      }
      if (nidAgeMax != null) {
        pCond += ' AND $pAgeExpr <= ?';
        pArgs.add(nidAgeMax);
      }
      pCond += ')';
      conditions.add(pCond);
      
      String oCond = '(o.rakm_komy IS NOT NULL AND LENGTH(o.rakm_komy) = 14';
      if (nidAgeMin != null) {
        oCond += ' AND $oAgeExpr >= ?';
        oArgs.add(nidAgeMin);
      }
      if (nidAgeMax != null) {
        oCond += ' AND $oAgeExpr <= ?';
        oArgs.add(nidAgeMax);
      }
      oCond += ')';
      conditions.add(oCond);
      
      query += conditions.join(' OR ');
      query += ')';
      args.addAll(pArgs);
      args.addAll(oArgs);
    }

    // Filter on National ID Birth Date
    if ((nidBirthDateMin != null && nidBirthDateMin.isNotEmpty) || (nidBirthDateMax != null && nidBirthDateMax.isNotEmpty)) {
      final pDateExpr = "date(CASE SUBSTR(p.rakm_komy, 1, 1) WHEN '3' THEN '20' ELSE '19' END || SUBSTR(p.rakm_komy, 2, 2) || '-' || SUBSTR(p.rakm_komy, 4, 2) || '-' || SUBSTR(p.rakm_komy, 6, 2))";
      final oDateExpr = "date(CASE SUBSTR(o.rakm_komy, 1, 1) WHEN '3' THEN '20' ELSE '19' END || SUBSTR(o.rakm_komy, 2, 2) || '-' || SUBSTR(o.rakm_komy, 4, 2) || '-' || SUBSTR(o.rakm_komy, 6, 2))";
      
      query += ' AND (';
      List<String> conditions = [];
      List<dynamic> pArgs = [];
      List<dynamic> oArgs = [];
      
      String pCond = '(p.rakm_komy IS NOT NULL AND LENGTH(p.rakm_komy) = 14';
      if (nidBirthDateMin != null && nidBirthDateMin.isNotEmpty) {
        pCond += ' AND $pDateExpr >= ?';
        pArgs.add(nidBirthDateMin);
      }
      if (nidBirthDateMax != null && nidBirthDateMax.isNotEmpty) {
        pCond += ' AND $pDateExpr <= ?';
        pArgs.add(nidBirthDateMax);
      }
      pCond += ')';
      conditions.add(pCond);
      
      String oCond = '(o.rakm_komy IS NOT NULL AND LENGTH(o.rakm_komy) = 14';
      if (nidBirthDateMin != null && nidBirthDateMin.isNotEmpty) {
        oCond += ' AND $oDateExpr >= ?';
        oArgs.add(nidBirthDateMin);
      }
      if (nidBirthDateMax != null && nidBirthDateMax.isNotEmpty) {
        oCond += ' AND $oDateExpr <= ?';
        oArgs.add(nidBirthDateMax);
      }
      oCond += ')';
      conditions.add(oCond);
      
      query += conditions.join(' OR ');
      query += ')';
      args.addAll(pArgs);
      args.addAll(oArgs);
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

    query += ' ORDER BY CASE WHEN o.code IS NULL THEN 1 ELSE 0 END, o.code ASC';

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
