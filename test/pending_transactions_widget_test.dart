import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pocket/models/pending_transaction_model.dart';
import 'package:pocket/providers/app_providers.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/widgets/pending_transactions_capsule.dart';
import 'package:pocket/widgets/pending_transactions_sheet.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PendingTransactionsCapsule returns empty SizedBox when queue is empty',
      (WidgetTester tester) async {
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PendingTransactionsCapsule(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(PendingTransactionsCapsule), findsOneWidget);
    expect(find.text('Detected Payment'), findsNothing);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });

  testWidgets('PendingTransactionsCapsule renders details and triggers approval when queue has items',
      (WidgetTester tester) async {
    final storage = await StorageService.init();
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );

    final item = PendingTransactionModel(
      id: 'pending_1',
      amount: 450.0,
      merchant: 'Swiggy Food',
      appSource: 'Google Pay',
      refId: 'UPI12345678',
      date: DateTime.now(),
      suggestedCategoryId: 'food',
      suggestedWalletId: 'default_cash',
    );

    container.read(pendingTransactionsProvider.notifier).addPending(item);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PendingTransactionsCapsule(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1 Detected Payment'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    // Tap quick-approve button
    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // The item should now be committed to transactions and queue emptied
    final pendingRemaining = container.read(pendingTransactionsProvider);
    expect(pendingRemaining, isEmpty);

    final transactions = container.read(transactionsProvider);
    expect(transactions.any((tx) => tx.amount == 450.0 && tx.title == 'Swiggy Food'), isTrue);
  });

  testWidgets('PendingTransactionsSheet displays all items and handles dismiss & Approve All',
      (WidgetTester tester) async {
    final storage = await StorageService.init();
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );

    final item1 = PendingTransactionModel(
      id: 'tx_1',
      amount: 300.0,
      merchant: 'Zomato',
      appSource: 'PhonePe',
      refId: 'PH99281',
      date: DateTime.now(),
      suggestedCategoryId: 'food',
      suggestedWalletId: 'default_cash',
    );

    final item2 = PendingTransactionModel(
      id: 'tx_2',
      amount: 150.0,
      merchant: 'Uber Auto',
      appSource: 'Google Pay',
      refId: 'GP88291',
      date: DateTime.now(),
      suggestedCategoryId: 'transport',
      suggestedWalletId: 'default_cash',
    );

    container.read(pendingTransactionsProvider.notifier).addPending(item1);
    container.read(pendingTransactionsProvider.notifier).addPending(item2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PendingTransactionsSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Detected Payments'), findsOneWidget);
    expect(find.text('2 unconfirmed transactions'), findsOneWidget);
    expect(find.text('Zomato'), findsOneWidget);
    expect(find.text('Uber Auto'), findsOneWidget);
    expect(find.text('Approve All'), findsOneWidget);

    // Dismiss first item
    final dismissButtons = find.descendant(
      of: find.byType(ListView),
      matching: find.byIcon(Icons.close_rounded),
    );
    expect(dismissButtons, findsNWidgets(2));
    await tester.tap(dismissButtons.first);
    await tester.pumpAndSettle();

    // Now 1 item remaining
    expect(container.read(pendingTransactionsProvider).length, 1);
    expect(find.text('1 unconfirmed transactions'), findsOneWidget);

    // Tap Approve All for remaining item
    await tester.tap(find.text('Approve All'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(container.read(pendingTransactionsProvider), isEmpty);
    final allTxs = container.read(transactionsProvider);
    expect(allTxs.any((tx) => tx.title == 'Uber Auto' && tx.amount == 150.0), isTrue);
  });
}
