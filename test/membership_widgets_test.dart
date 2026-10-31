import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:church_membership/data/models/family_models.dart';
import 'package:church_membership/data/models/tracking_models.dart';
import 'package:church_membership/providers/family_provider.dart';
import 'package:church_membership/providers/financial_provider.dart';
import 'package:church_membership/providers/lookup_provider.dart';
import 'package:church_membership/providers/tracking_provider.dart';
import 'package:church_membership/ui/widgets/search_picker.dart';
import 'package:church_membership/ui/widgets/identity_fields.dart';
import 'package:church_membership/ui/screens/financial/aid_screen.dart';
import 'package:church_membership/ui/screens/financial/expense_screen.dart';
import 'package:church_membership/ui/screens/tracking/confession_screen.dart';

class Families extends FamilyProvider {
  @override
  List<Family> get families => [Family(osraId: 1, osraName: 'أسرة الاختبار')];
  @override
  Future<void> loadFamilies({String? query}) async {}
  @override
  Future<List<Person>> getAllPersons() async => [
    Person(personId: 5, osraId: 1, personName: 'شخص الاختبار'),
  ];
}

class Tracking extends TrackingProvider {
  int? selected;
  @override
  Future<void> loadConfessions(int id) async {
    selected = id;
    notifyListeners();
  }
}

class Lookups extends LookupProvider {
  @override
  Future<void> loadAllLookups() async {}
}

class Financials extends FinancialProvider {
  int? selected;
  @override
  int? get lastFamilyId => selected;
  @override
  Future<void> loadFinancials(int id) async {
    selected = id;
    notifyListeners();
  }

  @override
  List<FixedAid> get fixedAids => [
    FixedAid(
      osraId: 1,
      countId: 1,
      countValue: 80,
      notes: 'مساعدة ثابتة محفوظة',
    ),
  ];
  @override
  List<VariableAid> get variableAids => [
    VariableAid(
      osraId: 1,
      count2Id: 1,
      countAdd: 20,
      notes: 'مساعدة متغيرة محفوظة',
    ),
  ];
  @override
  List<Expense> get expenses => [
    Expense(osraId: 1, masrofatId: 1, countValue: 30, masrof: 'مصروف مسجل'),
  ];
}

void main() {
  testWidgets(
    'confession offers people with family names on focus, filters and selects',
    (tester) async {
      final tracking = Tracking();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FamilyProvider>(create: (_) => Families()),
            ChangeNotifierProvider<TrackingProvider>.value(value: tracking),
          ],
          child: const MaterialApp(home: ConfessionScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(find.text('شخص الاختبار — أسرة الاختبار'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'اسرة الاختبار');
      await tester.pump();
      await tester.tap(find.text('شخص الاختبار — أسرة الاختبار'));
      await tester.pumpAndSettle();
      expect(tracking.selected, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tracking.dispose();
    },
  );

  testWidgets(
    'expenses select a family and display its registered rows on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FamilyProvider>(create: (_) => Families()),
            ChangeNotifierProvider<FinancialProvider>(
              create: (_) => Financials(),
            ),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ExpenseScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('أسرة الاختبار'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('مصروف مسجل: 30.0 ج.م'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('picker lists all on focus and filters Arabic text immediately', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPicker<String>(
            options: const ['أسرة إبراهيم', 'أسرة مريم'],
            label: (s) => s,
            hint: 'الأسر',
            onSelected: (s) => selected = s,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('أسرة إبراهيم'), findsOneWidget);
    expect(find.text('أسرة مريم'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ابراهيم');
    await tester.pump();
    expect(find.text('أسرة مريم'), findsNothing);
    await tester.tap(find.text('أسرة إبراهيم'));
    await tester.pump();
    expect(selected, 'أسرة إبراهيم');
  });

  testWidgets('identity fields allow manual input then fill and lock from ID', (
    tester,
  ) async {
    final id = TextEditingController();
    String? gov;
    int? age;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: id),
              IdentityFields(
                nationalId: id,
                onChanged: (g, _, a, _) {
                  gov = g;
                  age = a;
                },
              ),
            ],
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '40');
    await tester.enterText(fields.at(1), 'القاهرة');
    expect(age, 40);
    expect(gov, 'القاهرة');
    await tester.enterText(find.byType(TextField).first, '30405292601088');
    await tester.pump();
    expect(gov, 'سوهاج');
    expect(find.text('2004-05-29'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(
      find.descendant(of: fields, matching: find.byType(TextField)),
    )) {
      expect(field.readOnly, isTrue);
    }
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pump();
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    for (final field in tester.widgetList<TextField>(
      find.descendant(of: fields, matching: find.byType(TextField)),
    )) {
      expect(field.readOnly, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
    id.dispose();
  });

  testWidgets(
    'both aid tabs render stored rows and scroll on a phone with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FamilyProvider>(create: (_) => Families()),
            ChangeNotifierProvider<LookupProvider>(create: (_) => Lookups()),
            ChangeNotifierProvider<FinancialProvider>(
              create: (_) => Financials(),
            ),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AidScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('أسرة الاختبار'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('ملاحظات: مساعدة ثابتة محفوظة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('مساعدات متغيرة'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('ملاحظات: مساعدة متغيرة محفوظة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
