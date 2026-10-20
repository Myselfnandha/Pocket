import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocket/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SMS Auto-Import triggers UI update via ADB injection', (WidgetTester tester) async {
    // 1. Launch the app
    app.main();
    await tester.pumpAndSettle();

    // Give it a moment to stabilize
    await Future.delayed(const Duration(seconds: 2));

    // 2. Wait for the Pending Transactions Capsule to appear.
    // The python test coordinator script will inject an SMS via ADB while we wait.
    bool found = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      
      final badgeFinder = find.textContaining('Detected Payment');
      if (badgeFinder.evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }

    expect(found, isTrue, reason: 'Pending transactions capsule did not appear within 30 seconds of SMS injection.');

    // 3. Tap the capsule to open the sheet
    await tester.tap(find.textContaining('Detected Payment').first);
    await tester.pumpAndSettle();

    // 4. Verify the injected SMS payload was parsed correctly
    // Our python script will inject: "Spent $50.00 at Starbucks"
    expect(find.textContaining('Starbucks'), findsWidgets, reason: 'Expected merchant name not found in sheet');
    expect(find.textContaining('50.00'), findsWidgets, reason: 'Expected amount not found in sheet');

    print('E2E TEST PASSED: SMS successfully intercepted and parsed!');
  });
}
