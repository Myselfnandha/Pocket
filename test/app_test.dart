import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/recurring_model.dart';
import 'package:pocket/models/notification_model.dart';
import 'package:pocket/models/debt_model.dart';
import 'package:pocket/models/budget_model.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/services/backup_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pocket Data & Algorithm Tests', () {
    late StorageService storage;
    late BackupService backupService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      storage = await StorageService.init();
      backupService = BackupService(storage);
    });

    test('Initial seeded clean data loads correctly', () {
      final txs = storage.getTransactions();
      final wallets = storage.getWallets();
      final categories = storage.getCategories();

      expect(txs.isEmpty, isTrue);
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
        receiptImagePath: '/data/user/0/com.pocket/app_flutter/receipts/receipt_1.jpg',
        createdAt: DateTime.now(),
      );

      await storage.saveTransactions([newTx, ...storage.getTransactions()]);
      final updated = storage.getTransactions();

      expect(updated.length, equals(initialCount + 1));
      expect(updated.first.id, equals('new-123'));
      expect(updated.first.amount, equals(899.0));
      expect(updated.first.receiptImagePath, contains('receipt_1.jpg'));
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

    test('Recurring Rule due date automated creation generates transactions', () async {
      final pastDue = DateTime.now().subtract(const Duration(days: 1));
      final rule = RecurringRuleModel(
        id: 'rec-1',
        title: 'House Rent',
        amount: 15000.0,
        type: TransactionType.expense,
        categoryId: 'rent',
        walletId: 'bank',
        frequency: RecurringFrequency.monthly,
        dueDay: pastDue.day,
        nextDueDate: pastDue,
        templatePreset: RecurringTemplatePreset.rent,
        createdAt: pastDue.subtract(const Duration(days: 30)),
      );

      await storage.saveRecurringRules([rule]);
      final generatedCount = await storage.processDueRecurringRules();

      expect(generatedCount, equals(1));
      final txs = storage.getTransactions();
      expect(txs.any((t) => t.title == 'House Rent' && t.amount == 15000.0), isTrue);

      final notifs = storage.getNotifications();
      expect(notifs.any((n) => n.title.contains('House Rent')), isTrue);

      final updatedRules = storage.getRecurringRules();
      expect(updatedRules.first.nextDueDate.isAfter(DateTime.now()), isTrue);
    });

    test('Full JSON Database export and restore maintains complete state integrity', () async {
      final tx = TransactionModel(
        id: 'tx-json-1',
        title: 'Special Item',
        amount: 420.0,
        type: TransactionType.expense,
        categoryId: 'shopping',
        walletId: 'cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([tx]);

      final backupContent = backupService.exportJsonBackupString();

      // Clear all
      await storage.clearAllData();
      expect(storage.getTransactions().isEmpty, isTrue);

      // Restore
      final restored = await backupService.restoreFromJsonString(backupContent);
      expect(restored, isTrue);
      expect(storage.getTransactions().any((t) => t.id == 'tx-json-1'), isTrue);
    });

    test('Notification preferences and unread counts', () async {
      final notif = AppNotificationModel(
        id: 'notif-1',
        title: 'Budget Alert',
        message: '80% budget limit reached',
        type: NotificationType.budgetNearLimit,
        createdAt: DateTime.now(),
      );

      await storage.addNotification(notif);
      final list = storage.getNotifications();
      expect(list.length, equals(1));
      expect(list.first.isRead, isFalse);
    });

    test('DebtModel handles partial repayments and full settlement properly', () async {
      final debt = DebtModel(
        id: 'debt-1',
        personName: 'Rahul',
        phoneNumber: '+91 9876543210',
        totalAmount: 5000.0,
        remainingAmount: 5000.0,
        type: DebtType.lent,
        createdAt: DateTime.now(),
      );

      expect(debt.isSettled, isFalse);

      // Record partial payment of 2000
      final partial = debt.recordPayment(paymentAmount: 2000.0, note: 'GPay payment');
      expect(partial.remainingAmount, equals(3000.0));
      expect(partial.isSettled, isFalse);
      expect(partial.payments.length, equals(1));

      // Record final payment of 3000
      final settled = partial.recordPayment(paymentAmount: 3000.0, note: 'Cash');
      expect(settled.remainingAmount, equals(0.0));
      expect(settled.isSettled, isTrue);
      expect(settled.payments.length, equals(2));

      // Persist to storage
      await storage.saveDebts([settled]);
      final loaded = storage.getDebts();
      expect(loaded.length, equals(1));
      expect(loaded.first.personName, equals('Rahul'));
      expect(loaded.first.isSettled, isTrue);
    });

    test('CategoryBudgetModel calculates safe daily spend, progress, and persists properly', () async {
      final now = DateTime(2026, 8, 15);
      final budget = CategoryBudgetModel(
        id: 'budget-food',
        categoryId: 'food',
        monthlyLimit: 6000.0,
        isRolloverEnabled: true,
        createdAt: now,
        updatedAt: now,
      );

      // Current spent: 2600. Remaining: 3400. Total days in August = 31. Remaining days from 15th = (31 - 15 + 1) = 17 days.
      final safeDaily = budget.calculateDailySafeSpend(2600.0, referenceDate: now);
      expect(safeDaily, closeTo(3400.0 / 17, 0.01));

      // Progress calculation
      final progress = budget.calculateProgress(3000.0);
      expect(progress, equals(0.5));

      final overbudgetProgress = budget.calculateProgress(7500.0);
      expect(overbudgetProgress, equals(1.25));

      // Persist and retrieve from storage
      await storage.saveCategoryBudgets([budget]);
      final loaded = storage.getCategoryBudgets();
      expect(loaded.length, equals(1));
      expect(loaded.first.categoryId, equals('food'));
      expect(loaded.first.monthlyLimit, equals(6000.0));
      expect(loaded.first.isRolloverEnabled, isTrue);
    });

    test('Local Storage encrypts data blobs in SharedPreferences and migrates legacy plaintext', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Verify saved data in SharedPreferences has encrypted prefix enc:v1:
      final rawTransactions = prefs.getString('pocket_transactions');
      if (rawTransactions != null) {
        expect(rawTransactions.startsWith('enc:v1:'), isTrue);
      }

      // Test migration: simulate legacy plaintext stored in SharedPreferences
      await prefs.setString('pocket_wallets', '[{"id":"cash","name":"Cash Wallet","type":"cash","colorValue":4281116248,"createdAt":"2026-08-30T00:00:00.000"}]');
      
      // Re-initialize StorageService which triggers migration
      final reloadedStorage = await StorageService.init(prefs: prefs);
      final migratedWallets = reloadedStorage.getWallets();
      expect(migratedWallets.any((w) => w.id == 'cash'), isTrue);

      // Verify the raw string in SharedPreferences has been upgraded to encrypted
      final migratedRaw = prefs.getString('pocket_wallets');
      expect(migratedRaw != null && migratedRaw.startsWith('enc:v1:'), isTrue);
    });
  });
}
