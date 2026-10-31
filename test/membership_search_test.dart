import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:church_membership/data/models/family_models.dart';
import 'package:church_membership/data/models/national_identity.dart';
import 'package:church_membership/data/repositories/family_repository.dart';
import 'package:church_membership/data/repositories/search_repository.dart';
import 'package:church_membership/data/database/identity_migration.dart';

void main() {
  late Database db;
  late SearchRepository search;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final entry in {
      'osra': Family(osraName: '').toMap(),
      'person': Person(osraId: 0, personName: '').toMap(),
    }.entries) {
      await db.execute(
        'CREATE TABLE ${entry.key} (${entry.value.keys.map((k) => '$k ${k.endsWith('_id') || k == 'code' || k == 'number' ? 'INTEGER' : 'TEXT'}').join(',')})',
      );
    }
    await db.execute(
      'CREATE TABLE masrofat (osra_id INTEGER, count_value REAL)',
    );
    await db.insert(
      'osra',
      Family(osraId: 1, osraName: 'أسرة إبرآم', number: 99).toMap(),
    );
    await db.insert('osra', Family(osraId: 2, osraName: 'أسرة مريم').toMap());
    await db.insert(
      'osra',
      Family(osraId: 3, osraName: 'أسرة بلا أفراد').toMap(),
    );
    // Emulate old data: derived columns are absent or stale.
    await db.insert('person', {
      'person_id': 1,
      'osra_id': 1,
      'person_name': 'مَارِيَا',
      'rakm_komy': '30405292601088',
      'month': '1',
      'birth_date': null,
    });
    await db.insert(
      'person',
      Person(
        personId: 2,
        osraId: 2,
        personName: 'بطرس',
        birthDate: '2000-12-25',
        gender: 'ذكر',
        governorate: 'القاهرة',
        mobile: '012345',
      ).toMap(),
    );
    await db.insert('masrofat', {'osra_id': 1, 'count_value': 50});
    search = SearchRepository(database: db);
  });
  tearDown(() => db.close());

  test('head-only national ID appears in May search and birthdays', () async {
    // Reproduce the screenshot: the national ID is on Family Details, with no
    // rows in Family Members. Older records may lack the derived birth date.
    await db.insert('osra', {
      'osra_id': 4,
      'osra_name': 'sdcsdcs',
      'rakm_komy': '30405292601055',
      'birth_date': null,
    });
    expect(await PersonRepository(database: db).getPersonsByFamily(4), isEmpty);
    expect(
      (await search.complexSearch(
        name: 'sdcsdcs',
        birthMonths: ['5'],
      )).single['osra_id'],
      4,
    );
    final head = (await PersonRepository(
      database: db,
    ).getPersonsByBirthMonth(5)).singleWhere((p) => p.osraId == 4);
    expect(head.personName, 'sdcsdcs');
    expect(head.birthDate, '2004-05-29');
    expect(head.gender, 'ذكر');
    expect(head.personId, isNull);
    expect(
      await search.complexSearch(name: 'sdcsdcs', birthMonths: ['6']),
      isEmpty,
    );
    expect(await PersonRepository(database: db).getPersonsByFamily(4), isEmpty);
  });

  test(
    'saved manual head birthday participates without a national ID',
    () async {
      final families = FamilyRepository(database: db);
      await families.insertFamily(
        Family(
          osraId: 4,
          osraName: 'رب أسرة يدوي',
          birthDate: '1990-05-10',
          age: '36',
          gender: 'ذكر',
          governorate: 'القاهرة',
        ),
      );
      final saved = (await families.getFamilyById(4))!;
      await families.updateFamily(saved);
      expect(
        (await search.complexSearch(
          name: 'رب اسرة يدوي',
          birthMonths: ['٠٥'],
          ageMin: 36,
          ageMax: 36,
          nidGov: '01',
          nidGender: 'ذكر',
        )).single['osra_id'],
        4,
      );
      final birthdays = await PersonRepository(
        database: db,
      ).getPersonsByBirthMonth(5);
      expect(birthdays.map((p) => p.personName), ['رب أسرة يدوي', 'مَارِيَا']);
      expect((await families.getFamilyById(4))!.birthDate, '1990-05-10');
    },
  );

  test(
    'head month and member criteria cannot match different people',
    () async {
      await db.update('osra', {
        'rakm_komy': '30405292601055',
      }, where: 'osra_id = 2');
      expect(
        await search.complexSearch(name: 'بطرس', birthMonths: ['5']),
        isEmpty,
      );
      expect(
        await search.complexSearch(
          birthMonths: ['5'],
          nidGender: 'أنثى',
          name: 'مريم',
        ),
        isEmpty,
      );
      expect(
        await search.complexSearch(birthMonths: ['5'], job: 'مدرس'),
        isEmpty,
      );
      expect(
        await search.complexSearch(birthMonths: ['5'], stageIds: [10]),
        isEmpty,
      );
      expect(
        (await search.complexSearch(
          name: 'مريم',
          birthMonths: ['5'],
          nidGender: 'ذكر',
        )).single['osra_id'],
        2,
      );
    },
  );

  test(
    'birthday report deduplicates head/member within the same family',
    () async {
      await db.update('osra', {
        'rakm_komy': '٣٠٤٠٥٢٩٢٦٠١٠٨٨',
        'osra_name': 'اسم رب الأسرة',
      }, where: 'osra_id = 1');
      expect(
        await PersonRepository(database: db).getPersonsByBirthMonth(5),
        hasLength(1),
      );
      await db.insert(
        'osra',
        Family(osraId: 4, osraName: 'يدوي', birthDate: '1990-05-10').toMap(),
      );
      await db.insert(
        'person',
        Person(
          personId: 4,
          osraId: 4,
          personName: 'يدوي',
          birthDate: '1990-05-10',
        ).toMap(),
      );
      expect(
        await PersonRepository(database: db).getPersonsByBirthMonth(5),
        hasLength(2),
      );
      await db.insert(
        'osra',
        Family(
          osraId: 5,
          osraName: 'أسرة أخرى',
          birthDate: '1990-05-10',
        ).toMap(),
      );
      expect(
        await PersonRepository(database: db).getPersonsByBirthMonth(5),
        hasLength(3),
      );
    },
  );

  test(
    'version-zero legacy seed tables receive identity columns idempotently',
    () async {
      final legacy = db;
      await legacy.execute('DROP TABLE osra');
      await legacy.execute('DROP TABLE person');
      try {
        await legacy.execute(
          'CREATE TABLE osra (osra_id INTEGER, osra_name TEXT)',
        );
        await legacy.execute(
          'CREATE TABLE person (person_id INTEGER, person_name TEXT, birth_date TEXT, age TEXT)',
        );
        await ensureIdentityColumns(legacy);
        await ensureIdentityColumns(legacy);
        await legacy.insert('osra', {
          'osra_id': 1,
          'osra_name': 'اختبار',
          'gender': 'ذكر',
          'age': '30',
          'governorate': 'القاهرة',
          'birth_date': '1996-01-01',
        });
        await legacy.insert('person', {
          'person_id': 1,
          'person_name': 'اختبار',
          'gender': 'أنثى',
          'governorate': 'سوهاج',
        });
        expect((await legacy.query('osra')).single['gender'], 'ذكر');
      } finally {
        // The shared test connection is closed by tearDown.
      }
    },
  );

  test('combined member filters apply to the same matching member', () async {
    await db.insert(
      'person',
      Person(
        personId: 3,
        osraId: 1,
        personName: 'فرد آخر',
        birthDate: '2000-12-25',
      ).toMap(),
    );
    expect(
      await search.complexSearch(name: 'ماريا', birthMonths: ['12']),
      isEmpty,
    );
    expect(
      await search.complexSearch(name: 'ماريا', birthMonths: ['5']),
      hasLength(1),
    );
  });

  test('family quick search accepts member mobile and national ID', () async {
    expect(
      await FamilyRepository(database: db).getFamilies(query: '٠١٢٣٤٥'),
      hasLength(1),
    );
    expect(
      await FamilyRepository(database: db).getFamilies(query: '30405292601088'),
      hasLength(1),
    );
  });

  test(
    'blank searches include families with no members; expenses require recorded expenses',
    () async {
      expect(await search.complexSearch(name: '   '), hasLength(3));
      expect(
        (await search.complexSearch(expensesOnly: true)).single['osra_id'],
        1,
      );
      expect(
        await search.complexSearch(expensesOnly: true, name: 'مريم'),
        isEmpty,
      );
    },
  );
  test(
    'family and member names match Arabic variants and diacritics',
    () async {
      expect(
        (await search.complexSearch(name: 'اسرة ابرام')).single['osra_id'],
        1,
      );
      expect((await search.complexSearch(name: 'ماريا')).single['osra_id'], 1);
      expect(
        await FamilyRepository(database: db).getFamilies(query: 'ماريا'),
        hasLength(1),
      );
      expect(await search.searchPersons(name: 'ماريا'), hasLength(1));
    },
  );
  test(
    'legacy national IDs participate in birthdays, month, age, governorate and gender filters',
    () async {
      final people = await PersonRepository(
        database: db,
      ).getPersonsByBirthMonth(5);
      expect(people.single.birthDate, '2004-05-29');
      expect(
        (await search.complexSearch(birthMonths: ['05'])).single['osra_id'],
        1,
      );
      expect(
        (await search.complexSearch(
          nidGov: '26',
          nidGender: 'أنثى',
          nidBirthDateMin: '2004-05-29',
          nidBirthDateMax: '2004-05-29',
        )).single['osra_id'],
        1,
      );
      final age = NationalIdentity.parse('30405292601088')!.age;
      expect(
        (await search.complexSearch(
          ageMin: age,
          ageMax: age,
          birthMonths: ['5'],
        )).single['osra_id'],
        1,
      );
      expect(await search.complexSearch(birthMonths: ['1']), isEmpty);
      expect(await search.complexSearch(personCount: 99), isEmpty);
    },
  );
  test(
    'manual identity values survive persistence and participate in filters',
    () async {
      final p = Person.fromMap(
        (await db.query('person', where: 'person_id = 2')).single,
      );
      expect(p.gender, 'ذكر');
      expect(p.governorate, 'القاهرة');
      expect(p.month, '12');
      expect(
        (await search.complexSearch(
          nidGov: '01',
          nidGender: 'ذكر',
          birthMonths: ['12'],
        )).single['osra_id'],
        2,
      );
    },
  );
  test('national ID writes canonical fields and rejects invalid dates', () {
    final data = Person(
      osraId: 1,
      personName: 'اختبار',
      rakmKomy: '٣٠٤٠٥٢٩٢٦٠١٠٨٨',
    ).toMap();
    expect(data['birth_date'], '2004-05-29');
    expect(data['month'], '5');
    expect(data['governorate'], 'سوهاج');
    expect(data['gender'], 'أنثى');
    expect(
      Person(
        osraId: 1,
        personName: 'يدوي',
        birthDate: '1990-01-01',
        age: '40',
      ).toMap()['age'],
      '40',
    );
    expect(NationalIdentity.parse('30402312601088'), isNull);
    expect(NationalIdentity.parse('30413292601088'), isNull);
    expect(
      Family(
        osraName: 'اختبار',
        rakmKomy: '30405292601088',
      ).toMap().containsKey('month'),
      isFalse,
    );
  });
}
