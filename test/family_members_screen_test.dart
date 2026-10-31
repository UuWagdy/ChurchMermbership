import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:church_membership/data/models/family_models.dart';
import 'package:church_membership/providers/family_provider.dart';
import 'package:church_membership/providers/lookup_provider.dart';
import 'package:church_membership/ui/screens/family/family_form_screen.dart';

class _Families extends FamilyProvider {
  int calls = 0;
  bool fail = false;
  @override
  Future<List<Person>> getPersons(int id) async {
    calls++;
    if (fail) throw Exception('offline');
    return [Person(personId: 2, osraId: id, personName: 'فرد الاختبار')];
  }
}

class _Lookups extends LookupProvider {
  final ready = Completer<void>();
  @override
  Future<void> loadAllLookups() => ready.future;
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Families families,
    _Lookups lookup,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FamilyProvider>.value(value: families),
          ChangeNotifierProvider<LookupProvider>.value(value: lookup),
        ],
        child: MaterialApp(
          onGenerateRoute: (_) => MaterialPageRoute(
            settings: RouteSettings(
              arguments: Family(osraId: 1, osraName: 'أسرة الاختبار'),
            ),
            builder: (_) => const FamilyFormScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('أفراد الأسرة'));
    await tester.pumpAndSettle();
  }

  testWidgets('members appear while lookup requests are still pending', (
    tester,
  ) async {
    final families = _Families();
    final lookup = _Lookups();
    await open(tester, families, lookup);
    expect(families.calls, 1);
    expect(find.text('فرد الاختبار'), findsOneWidget);
    lookup.ready.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    families.dispose();
    lookup.dispose();
  });

  testWidgets('member failure shows retry and can recover', (tester) async {
    final families = _Families()..fail = true;
    final lookup = _Lookups()..ready.complete();
    await open(tester, families, lookup);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    families.fail = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('فرد الاختبار'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    families.dispose();
    lookup.dispose();
  });
}
