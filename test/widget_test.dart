import 'package:flutter_test/flutter_test.dart';
import 'package:abona_flemoon/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AbonaFlemoonApp());

    // Verify that login screen is shown.
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
