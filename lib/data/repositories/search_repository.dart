import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;
import '../database/database_helper.dart';
import '../models/national_identity.dart';

class SearchRepository {
  final Database? _database;
  SearchRepository({Database? database}) : _database = database;
  final _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> complexSearch({
    bool expensesOnly = false,
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
    final db = _database ?? await _dbHelper.database;
    // Use the same canonical values for SQLite and PostgreSQL, including legacy
    // records where only the national ID was stored.
    final families = await db.query('osra');
    final persons = (await db.query(
      'person',
    )).map(NationalIdentity.normalize).toList();
    final members = <int, List<Map<String, dynamic>>>{};
    for (final p in persons) {
      members.putIfAbsent((p['osra_id'] as num).toInt(), () => []).add(p);
    }
    final expenseFamilies = expensesOnly
        ? (await db.query('masrofat')).map((e) => e['osra_id']).toSet()
        : <Object?>{};
    bool contains(dynamic value, String? query) =>
        query == null ||
        normalizeSearch(query).isEmpty ||
        normalizeSearch(
          value?.toString() ?? '',
        ).contains(normalizeSearch(query));
    bool selected(dynamic value, List<int>? ids) =>
        ids == null || ids.isEmpty || ids.contains(value);
    bool range(int? value, int? min, int? max) =>
        (min == null && max == null) ||
        (value != null &&
            (min == null || value >= min) &&
            (max == null || value <= max));
    bool identityMatches(Map<String, dynamic> p) {
      final date = DateTime.tryParse(p['birth_date']?.toString() ?? '');
      final dateText = date?.toIso8601String().split('T').first;
      return (nidGov == null ||
              nidGov.isEmpty ||
              p['governorate'] == NationalIdentity.governorates[nidGov]) &&
          (nidGender == null ||
              nidGender.isEmpty ||
              p['gender'] == nidGender) &&
          range(
            int.tryParse(p['age']?.toString().split(' ').first ?? ''),
            nidAgeMin,
            nidAgeMax,
          ) &&
          (nidBirthDateMin == null ||
              nidBirthDateMin.isEmpty ||
              (dateText != null && dateText.compareTo(nidBirthDateMin) >= 0)) &&
          (nidBirthDateMax == null ||
              nidBirthDateMax.isEmpty ||
              (dateText != null && dateText.compareTo(nidBirthDateMax) <= 0));
    }

    final result = <Map<String, dynamic>>[];
    for (final raw in families) {
      final f = NationalIdentity.normalize(raw);
      final people = members[(f['osra_id'] as num).toInt()] ?? [];
      if (expensesOnly && !expenseFamilies.contains(f['osra_id'])) {
        continue;
      }
      if (!selected(f['area_id'], areaIds) ||
          (streetId != null && f['street_id'] != streetId) ||
          !selected(f['hala_egtimaia_id'], socialStatusIds) ||
          !selected(f['e_s_id'], economicStatusIds) ||
          (personCount != null && people.length != personCount)) {
        continue;
      }
      final familyNameMatches = contains(f['osra_name'], name);
      final familyPhoneMatches = contains(f['phone'], mobile);
      // The family row also stores a person: the family head. Evaluate all
      // personal criteria against one candidate so a head's birthday cannot
      // accidentally combine with a different member's age or identity.
      bool matchesPerson(Map<String, dynamic> p) =>
          (familyNameMatches || contains(p['person_name'], name)) &&
          (familyPhoneMatches || contains(p['mobile'], mobile)) &&
          selected(p['stage_id'], stageIds) &&
          selected(p['hala_sehia_id'], healthStatusIds) &&
          selected(p['mostwa_id'], mostwaIds) &&
          selected(p['karaba_id'], karabaIds) &&
          (fatherId == null || p['father_id'] == fatherId) &&
          contains(p['wazefa'], job) &&
          range(
            int.tryParse(p['age']?.toString().split(' ').first ?? ''),
            ageMin,
            ageMax,
          ) &&
          (birthMonths == null ||
              birthMonths.isEmpty ||
              birthMonths.any(
                (m) =>
                    int.tryParse(normalizeDigits(m)) ==
                    int.tryParse(p['month']?.toString() ?? ''),
              )) &&
          identityMatches(p);
      final matchingHead = matchesPerson({
        ...f,
        'person_name': f['osra_name'],
        'mobile': f['phone'],
      });
      if (!matchingHead && !people.any(matchesPerson)) {
        continue;
      }
      result.add({...f, 'member_count': people.length});
    }
    result.sort((a, b) {
      final ac = a['code'] as num?;
      final bc = b['code'] as num?;
      if (ac == null && bc != null) return 1;
      if (bc == null && ac != null) return -1;
      final order = ac == null ? 0 : ac.compareTo(bc!);
      return order != 0
          ? order
          : normalizeSearch(
              a['osra_name'].toString(),
            ).compareTo(normalizeSearch(b['osra_name'].toString()));
    });
    return result;
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
    final db = _database ?? await _dbHelper.database;

    final people = await db.query('person');
    final families = {for (final f in await db.query('osra')) f['osra_id']: f};
    bool contains(dynamic value, String? term) => normalizeSearch(
      value?.toString() ?? '',
    ).contains(normalizeSearch(term ?? ''));
    return people.map(NationalIdentity.normalize).where((p) {
      final f = families[p['osra_id']];
      return contains(p['person_name'], name) &&
          contains(p['rakm_komy'], nationalId) &&
          contains(p['mobile'], mobile) &&
          contains(p['wazefa'], job) &&
          (areaId == null || f?['area_id'] == areaId) &&
          (streetId == null || f?['street_id'] == streetId) &&
          (socialStatusId == null || p['hala_egtimaia_id'] == socialStatusId) &&
          (economicStatusId == null || f?['e_s_id'] == economicStatusId) &&
          (stageId == null || p['stage_id'] == stageId) &&
          (healthStatusId == null || p['hala_sehia_id'] == healthStatusId) &&
          (mostwaId == null || p['mostwa_id'] == mostwaId) &&
          (karabaId == null || p['karaba_id'] == karabaId);
    }).toList();
  }
}
