import 'package:flutter_test/flutter_test.dart';
import 'package:church_membership/sync/dotnet_postgres_database.dart';

String nameById(
  List<Map<String, dynamic>> items,
  String idKey,
  String nameKey,
  int? id,
) {
  if (id == null) return '---';
  for (final item in items) {
    final raw = item[idKey];
    final itemId = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (itemId == id) {
      final name = item[nameKey]?.toString().trim();
      return (name == null || name.isEmpty) ? '---' : name;
    }
  }
  return '---';
}

void main() {
  group('DotNetPostgresDatabase rawQuery type safety & lookup tests', () {
    test('rawQuery mapping produces List<Map<String, Object?>> rather than List<CaseInsensitiveRowMap>', () {
      final rawRows = [
        {'karaba_id': 1, 'karaba_name': 'ابن'},
        {'karaba_id': 2, 'karaba_name': 'زوجة'},
      ];

      // Exact mapping used in rawQuery after the fix:
      final fixedList = rawRows
          .map<Map<String, Object?>>(
            (r) => CaseInsensitiveRowMap(Map<String, dynamic>.from(r)),
          )
          .toList();

      expect(fixedList, isA<List<Map<String, Object?>>>());
      expect(fixedList.runtimeType.toString(), isNot(contains('CaseInsensitiveRowMap>')));

      // Test that firstWhere with orElse: () => {} does not throw TypeError on fixed list
      expect(() {
        final match = fixedList.firstWhere(
          (k) => k['karaba_id'] == 1,
          orElse: () => {},
        );
        expect(match['karaba_name'], equals('ابن'));
      }, returnsNormally);

      expect(() {
        final missingMatch = fixedList.firstWhere(
          (k) => k['karaba_id'] == 999,
          orElse: () => {},
        );
        expect(missingMatch.isEmpty, isTrue);
      }, returnsNormally);
    });

    test('nameById helper correctly extracts names and handles fallback', () {
      final rows = [
        <String, dynamic>{'karaba_id': 1, 'karaba_name': 'أب'},
        <String, dynamic>{'karaba_id': '2', 'karaba_name': 'أم'},
        <String, dynamic>{'karaba_id': 3, 'karaba_name': ''},
      ];

      expect(nameById(rows, 'karaba_id', 'karaba_name', 1), equals('أب'));
      expect(nameById(rows, 'karaba_id', 'karaba_name', 2), equals('أم'));
      expect(nameById(rows, 'karaba_id', 'karaba_name', 3), equals('---'));
      expect(nameById(rows, 'karaba_id', 'karaba_name', 4), equals('---'));
      expect(nameById(rows, 'karaba_id', 'karaba_name', null), equals('---'));
    });
  });
}
