import 'package:flutter_test/flutter_test.dart';
import 'package:church_membership/data/database/database_helper.dart';
import 'package:church_membership/data/models/family_models.dart';
import 'package:church_membership/data/repositories/family_repository.dart';
import 'package:church_membership/data/repositories/financial_repository.dart';
import 'package:church_membership/data/repositories/search_repository.dart';
import 'package:church_membership/sync/server_config.dart';

void main() {
  const url = String.fromEnvironment('MEMBERSHIP_TEST_URL');
  test(
    'PostgreSQL: legacy birthdays, searches, financial rows and manual identity round trip',
    () async {
      ServerConfig.isServerMode = true;
      ServerConfig.baseUrl = url;
      addTearDown(() => DatabaseHelper().closeDatabase());
      final search = SearchRepository();
      final families = await search.complexSearch();
      expect(families, hasLength(2));
      expect(await search.complexSearch(name: 'اسرة اختبار'), hasLength(1));
      expect(await search.complexSearch(name: 'ماريا'), hasLength(1));
      final result = await search.complexSearch(birthMonths: ['5']);
      expect(result, hasLength(1));
      expect(await search.complexSearch(expensesOnly: true), hasLength(1));
      expect(
        await search.complexSearch(expensesOnly: true, name: 'فارغة'),
        isEmpty,
      );
      final id = result.single['osra_id'] as int;
      expect(
        (await PersonRepository().getPersonsByBirthMonth(5)).single.birthDate,
        '2004-05-29',
      );
      expect(await FinancialRepository().getFixedAidByFamily(id), hasLength(1));
      expect(
        await FinancialRepository().getVariableAidByFamily(id),
        hasLength(1),
      );
      expect(await FinancialRepository().getExpensesByFamily(id), hasLength(1));
      await PersonRepository().insertPerson(
        Person(
          osraId: id,
          personName: 'فرد يدوي',
          gender: 'ذكر',
          governorate: 'القاهرة',
          birthDate: '1990-12-25',
        ),
      );
      final person = (await PersonRepository().getPersonsByFamily(
        id,
      )).firstWhere((p) => p.personName == 'فرد يدوي');
      expect(person.gender, 'ذكر');
      expect(person.governorate, 'القاهرة');
      expect(
        await search.complexSearch(nidGov: '01', birthMonths: ['12']),
        hasLength(1),
      );
      // Head-only case from Family Details: no member row is required.
      final headFamily = families.singleWhere((f) => f['osra_id'] != id);
      final headId = headFamily['osra_id'] as int;
      await FamilyRepository().updateFamily(
        Family(osraId: headId, osraName: 'sdcsdcs', rakmKomy: '30405292601055'),
      );
      expect(await PersonRepository().getPersonsByFamily(headId), isEmpty);
      expect(
        (await search.complexSearch(
          name: 'sdcsdcs',
          birthMonths: ['5'],
        )).single['osra_id'],
        headId,
      );
      final head = (await PersonRepository().getPersonsByBirthMonth(
        5,
      )).singleWhere((p) => p.osraId == headId);
      expect(head.personName, 'sdcsdcs');
      expect(head.birthDate, '2004-05-29');
      expect(head.personId, isNull);
    },
    skip: url.isEmpty,
  );
}
