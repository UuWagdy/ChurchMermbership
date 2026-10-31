import 'package:flutter_test/flutter_test.dart';
import 'package:church_membership/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChurchMembershipApp());

    // Verify that login screen is shown.
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
