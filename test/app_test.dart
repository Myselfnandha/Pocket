import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Pocket Data & Algorithm Tests', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
    });

    test('Initial seeded clean data loads correctly', () {
      final txs = storage.getTransactions();
      final wallets = storage.getWallets();
      final categories = storage.getCategories();

      expect(txs.isEmpty, isTrue); // Clean initial state with 0 dummy data
      expect(wallets.isNotEmpty, isTrue);
      expect(categories.isNotEmpty, isTrue);
      expect(wallets.any((w) => w.id == 'cash'), isTrue);
      expect(categories.any((c) => c.id == 'food'), isTrue);
    });

    test('Category Auto-Suggestion matches exact past title', () {
      final txs = [
        TransactionModel(
          id: '1',
          title: 'Starbucks Coffee',
          amount: 350,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'cash',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      final suggested = storage.suggestCategoryForTitle(
        'Starbucks Coffee',
        txs,
        defaultCategories,
      );

      expect(suggested, equals('food'));
    });

    test('Category Auto-Suggestion matches keyword heuristics', () {
      final suggestedZomato = storage.suggestCategoryForTitle(
        'Dinner on Zomato',
        [],
        defaultCategories,
      );
      expect(suggestedZomato, equals('food'));

      final suggestedUber = storage.suggestCategoryForTitle(
        'Uber cab ride',
        [],
        defaultCategories,
      );
      expect(suggestedUber, equals('transport'));

      final suggestedSalary = storage.suggestCategoryForTitle(
        'August Salary credit',
        [],
        defaultCategories,
      );
      expect(suggestedSalary, equals('salary'));
    });

    test('Adding new transaction persists properly', () async {
      final initialCount = storage.getTransactions().length;
      final newTx = TransactionModel(
        id: 'new-123',
        title: 'Books on Amazon',
        amount: 899.0,
        type: TransactionType.expense,
        categoryId: 'shopping',
        walletId: 'bank',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await storage.saveTransactions([newTx, ...storage.getTransactions()]);
      final updated = storage.getTransactions();

      expect(updated.length, equals(initialCount + 1));
      expect(updated.first.id, equals('new-123'));
      expect(updated.first.amount, equals(899.0));
    });

    test('Updating existing transaction updates values properly', () async {
      final newTx = TransactionModel(
        id: 'tx-1',
        title: 'Initial Title',
        amount: 500.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([newTx]);

      final modifiedTx = newTx.copyWith(title: 'Modified Title', amount: 1999.0);
      final currentList = storage.getTransactions();
      final updatedList = currentList.map((t) => t.id == modifiedTx.id ? modifiedTx : t).toList();
      await storage.saveTransactions(updatedList);

      final reloaded = storage.getTransactions().firstWhere((t) => t.id == newTx.id);
      expect(reloaded.title, equals('Modified Title'));
      expect(reloaded.amount, equals(1999.0));
    });

    test('User Settings save and load with Theme Mode configuration', () async {
      final initialSettings = storage.getSettings();
      final newSettings = initialSettings.copyWith(
        themeMode: AppThemeMode.manual,
        manualThemeStyle: ManualThemeStyle.pureBlack,
        isPureBlackEnabled: true,
        showCategoryTags: false,
      );

      await storage.saveSettings(newSettings);
      final reloadedSettings = storage.getSettings();

      expect(reloadedSettings.themeMode, equals(AppThemeMode.manual));
      expect(reloadedSettings.manualThemeStyle, equals(ManualThemeStyle.pureBlack));
      expect(reloadedSettings.isPureBlackEnabled, isTrue);
      expect(reloadedSettings.showCategoryTags, isFalse);
    });
  });
}
