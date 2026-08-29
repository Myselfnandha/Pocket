import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket/providers/app_providers.dart';
import 'package:pocket/screens/onboarding/onboarding_screen.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/widgets/balance_card.dart';
import 'package:pocket/widgets/quick_add_transaction_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('BalanceCard renders total balance and metric labels', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BalanceCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('OnboardingScreen renders welcome slide and navigation buttons without skip', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Welcome to Pocket'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsNothing); // Skip button removed
  });

  testWidgets('QuickAddTransactionDialog renders correctly with presets and switches type', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickAddTransactionDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quick Transaction'), findsOneWidget);
    expect(find.text('- Expense'), findsOneWidget);
    expect(find.text('+ Income'), findsOneWidget);
    expect(find.text('+₹50'), findsOneWidget);
    expect(find.text('+₹100'), findsOneWidget);
    expect(find.text('Quick Save'), findsOneWidget);
    expect(find.text('More Details'), findsOneWidget);

    // Tap a quick amount preset
    await tester.tap(find.text('+₹50'));
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);

    // Switch to Income
    await tester.tap(find.text('+ Income'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsWidgets);
  });
}

