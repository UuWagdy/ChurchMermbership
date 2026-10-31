import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:church_membership/data/models/family_models.dart';
import 'package:church_membership/data/repositories/family_repository.dart';
import 'package:church_membership/providers/family_provider.dart';
import 'package:church_membership/ui/screens/reports/birthdays_screen.dart';

class DatabaseFamilies extends FamilyProvider {
  DatabaseFamilies(this.repository);
  final PersonRepository repository;
  Future<List<Person>>? request;
  @override
  Future<List<Person>> getBirthdays(int month) =>
      request = repository.getPersonsByBirthMonth(month);
}

void main() {
  testWidgets(
    'May shows saved family head and enables printing without members',
    (tester) async {
      late Database db;
      late DatabaseFamilies families;
      await tester.runAsync(() async {
        sqfliteFfiInit();
        db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        await db.execute(
          'CREATE TABLE osra (osra_id INTEGER, osra_name TEXT, rakm_komy TEXT)',
        );
        await db.execute(
          'CREATE TABLE person (person_id INTEGER, osra_id INTEGER, person_name TEXT)',
        );
        await db.insert('osra', {
          'osra_id': 1,
          'osra_name': 'sdcsdcs',
          'rakm_komy': '30405292601055',
        });
        families = DatabaseFamilies(PersonRepository(database: db));
        await tester.pumpWidget(
          ChangeNotifierProvider<FamilyProvider>(
            create: (_) => families,
            child: const MaterialApp(home: BirthdaysScreen()),
          ),
        );
        await families.request;
      });
      addTearDown(() => tester.runAsync(db.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('شهر 5').last);
        await tester.pump();
        await families.request;
      });
      await tester.pumpAndSettle();
      expect(find.text('sdcsdcs'), findsOneWidget);
      expect(find.text('تاريخ الميلاد: 2004-05-29'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(await tester.runAsync(() => db.query('person')), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
