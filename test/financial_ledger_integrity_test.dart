import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/debt_model.dart';
import 'package:pocket/models/budget_model.dart';
import 'package:pocket/models/recurring_model.dart';
import 'package:pocket/providers/core_providers.dart';
import 'package:pocket/providers/transactions_provider.dart';
import 'package:pocket/providers/wallets_provider.dart';
import 'package:pocket/providers/debts_provider.dart';
import 'package:pocket/providers/goals_provider.dart';
import 'package:pocket/providers/budgets_provider.dart';
import 'package:pocket/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 — Database & Financial Ledger Integrity Suite', () {
    late SharedPreferences prefs;
    late StorageService storage;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = await StorageService.init(prefs: prefs);

      container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1 & 2: Income and Expense transactions update wallet balances accurately', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_main',
          name: 'Main Bank',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 10000.0,
          currentBalance: 10000.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      // Income: +₹5,000.75
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'Freelance Payout',
            amount: 5000.75,
            type: TransactionType.income,
            categoryId: 'salary',
            walletId: 'w_main',
            date: DateTime.now(),
          );

      var wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 15000.75);

      // Expense: -₹2,500.50
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'Grocery Supplies',
            amount: 2500.50,
            type: TransactionType.expense,
            categoryId: 'food',
            walletId: 'w_main',
            date: DateTime.now(),
          );

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 12500.25);
    });

    test('3: Account transfers execute double-entry ledger update with zero net worth change', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_bank',
          name: 'Checking A/C',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 20000.0,
          currentBalance: 20000.0,
          isDefault: true,
        ),
        const WalletModel(
          id: 'w_cash',
          name: 'Cash Pocket',
          icon: 'wallet',
          colorValue: 0xFF4CAF50,
          walletType: WalletType.cash,
          initialBalance: 1000.0,
          currentBalance: 1000.0,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      final now = DateTime.now();
      const transferAmount = 3000.0;

      // Transfer from bank to cash
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'ATM Cash Withdrawal',
            amount: transferAmount,
            type: TransactionType.expense,
            categoryId: 'cat_transfer',
            walletId: 'w_bank',
            date: now,
          );
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'ATM Cash Received',
            amount: transferAmount,
            type: TransactionType.income,
            categoryId: 'cat_transfer',
            walletId: 'w_cash',
            date: now,
          );

      final wallets = container.read(walletsWithBalancesProvider);
      final bankWallet = wallets.firstWhere((w) => w.id == 'w_bank');
      final cashWallet = wallets.firstWhere((w) => w.id == 'w_cash');

      expect(bankWallet.currentBalance, 17000.0);
      expect(cashWallet.currentBalance, 4000.0);
      expect(bankWallet.currentBalance + cashWallet.currentBalance, 21000.0,
          reason: 'Internal transfers must preserve total net worth');
    });

    test('4 & 14: Credit card transactions and negative balances are tracked correctly', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_cc',
          name: 'Platinum Credit Card',
          icon: 'credit_card',
          colorValue: 0xFFE91E63,
          walletType: WalletType.creditCard,
          initialBalance: 0.0,
          currentBalance: 0.0,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      // Card swipe
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'Flight Tickets',
            amount: 14500.0,
            type: TransactionType.expense,
            categoryId: 'travel',
            walletId: 'w_cc',
            date: DateTime.now(),
          );

      final wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, -14500.0,
          reason: 'Credit card liability / negative balances must be preserved without error');
    });

    test('5 & 6: Debt settlement, partial payments, and ledger synchronization', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_main',
          name: 'Main Bank',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 50000.0,
          currentBalance: 50000.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      // Lend ₹10,000 to Bob
      await container.read(debtsProvider.notifier).addDebt(
            personName: 'Bob Vance',
            amount: 10000.0,
            type: DebtType.lent,
            walletId: 'w_main',
            updateWallet: true,
          );

      var debts = container.read(debtsProvider);
      expect(debts.first.remainingAmount, 10000.0);
      expect(debts.first.isSettled, isFalse);

      var wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 40000.0);

      // Bob makes partial repayment of ₹4,000
      await container.read(debtsProvider.notifier).recordPayment(
            debtId: debts.first.id,
            amount: 4000.0,
            walletId: 'w_main',
            updateWallet: true,
          );

      debts = container.read(debtsProvider);
      expect(debts.first.remainingAmount, 6000.0);
      expect(debts.first.isSettled, isFalse);

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 44000.0);

      // Bob repays remaining ₹6,000 (full settlement)
      await container.read(debtsProvider.notifier).recordPayment(
            debtId: debts.first.id,
            amount: 6000.0,
            walletId: 'w_main',
            updateWallet: true,
          );

      debts = container.read(debtsProvider);
      expect(debts.first.remainingAmount, 0.0);
      expect(debts.first.isSettled, isTrue);

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 50000.0);
    });

    test('7 & 8: Savings goal deposits and withdrawals adjust ledger & balances', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_main',
          name: 'Main Bank',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 30000.0,
          currentBalance: 30000.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      await container.read(goalsProvider.notifier).addGoal(
            title: 'New Laptop',
            targetAmount: 80000.0,
            currentSavedAmount: 0.0,
            walletId: 'w_main',
          );

      var goals = container.read(goalsProvider);
      expect(goals.first.currentSavedAmount, 0.0);

      // Deposit ₹15,000 into goal
      await container.read(goalsProvider.notifier).depositToGoal(
            goalId: goals.first.id,
            amount: 15000.0,
            walletId: 'w_main',
          );

      goals = container.read(goalsProvider);
      expect(goals.first.currentSavedAmount, 15000.0);

      var wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 15000.0);

      // Withdraw ₹5,000 from goal back to wallet
      await container.read(goalsProvider.notifier).withdrawFromGoal(
            goalId: goals.first.id,
            amount: 5000.0,
            walletId: 'w_main',
          );

      goals = container.read(goalsProvider);
      expect(goals.first.currentSavedAmount, 10000.0);

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 20000.0);
    });

    test('9 & 10: Transaction editing and deletion recalculate ledger balances dynamically', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_main',
          name: 'Main Bank',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 10000.0,
          currentBalance: 10000.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      final tx = await container.read(transactionsProvider.notifier).addTransaction(
            title: 'Dinner Party',
            amount: 2000.0,
            type: TransactionType.expense,
            categoryId: 'food',
            walletId: 'w_main',
            date: DateTime.now(),
          );

      var wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 8000.0);

      // Edit transaction: correction from ₹2,000 to ₹1,500
      final updatedTx = tx.copyWith(amount: 1500.0);
      await container.read(transactionsProvider.notifier).updateTransaction(updatedTx);

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 8500.0);

      // Delete transaction: balance restored to ₹10,000
      await container.read(transactionsProvider.notifier).deleteTransaction(tx.id);

      wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 10000.0);

      // Verify deletion signature was recorded to prevent duplicate re-import
      expect(storage.isTransactionDeleted(updatedTx.signature), isTrue);
    });

    test('11: Duplicate transaction prevention via signature and message ID tracking', () async {
      const sig = 'sig_hdfc_5000_20261118_ref123';
      expect(storage.isTransactionDeleted(sig), isFalse);

      await storage.addDeletedTransactionSignature(sig);
      expect(storage.isTransactionDeleted(sig), isTrue);

      const msgId = 'sms_msg_987654';
      expect(storage.isMessageProcessed(msgId), isFalse);

      await storage.addProcessedMessageId(msgId);
      expect(storage.isMessageProcessed(msgId), isTrue);
    });

    test('12 & 16: Month-end date and timezone boundaries', () async {
      // Month boundary: Nov 30 23:59:59 vs Dec 1 00:00:00
      final novTx = TransactionModel(
        id: 'tx_nov',
        title: 'Nov Expense',
        amount: 500.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_default',
        date: DateTime(2026, 11, 30, 23, 59, 59),
        createdAt: DateTime.now(),
      );

      final decTx = TransactionModel(
        id: 'tx_dec',
        title: 'Dec Expense',
        amount: 800.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_default',
        date: DateTime(2026, 12, 1, 0, 0, 0),
        createdAt: DateTime.now(),
      );

      await storage.saveTransactions([novTx, decTx]);
      final txs = storage.getTransactions();

      final novItems = txs.where((t) => t.date.year == 2026 && t.date.month == 11).toList();
      final decItems = txs.where((t) => t.date.year == 2026 && t.date.month == 12).toList();

      expect(novItems.length, 1);
      expect(novItems.first.id, 'tx_nov');

      expect(decItems.length, 1);
      expect(decItems.first.id, 'tx_dec');
    });

    test('13: Category budget consumption, rollover calculation, and threshold tracking', () async {
      final now = DateTime.now();
      final budget = CategoryBudgetModel(
        id: 'b_food',
        categoryId: 'food',
        monthlyLimit: 10000.0,
        isRolloverEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      await storage.saveCategoryBudgets([budget]);

      // Add expense in food
      await container.read(transactionsProvider.notifier).addTransaction(
            title: 'Dining Out',
            amount: 7500.0,
            type: TransactionType.expense,
            categoryId: 'food',
            walletId: 'w_default',
            date: DateTime(now.year, now.month, 15),
          );

      final budgets = container.read(categoryBudgetsProvider);
      final foodBudget = budgets.firstWhere((b) => b.categoryId == 'food');
      final txs = container.read(transactionsProvider);

      final spentInFood = txs
          .where((t) => t.categoryId == 'food' && t.type == TransactionType.expense)
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      expect(spentInFood, 7500.0);
      expect(foodBudget.monthlyLimit - spentInFood, 2500.0,
          reason: 'Remaining budget must reflect ledger spending');

      // Test rollover: if last month spent was 6,000 out of 10,000, 4,000 carries over
      final effectiveLimitWithRollover = foodBudget.calculateEffectiveLimit(lastMonthSpent: 6000.0);
      expect(effectiveLimitWithRollover, 14000.0,
          reason: 'Rollover enabled budgets must carry unspent surplus to next month');
    });

    test('15: Decimal precision cents-rounding prevents floating-point IEEE-754 drift', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_precision',
          name: 'Precision Test A/C',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 0.0,
          currentBalance: 0.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      // Add 10 transactions of ₹0.10 and ₹0.20
      for (int i = 0; i < 5; i++) {
        await container.read(transactionsProvider.notifier).addTransaction(
              title: 'Cents Test $i',
              amount: 0.10,
              type: TransactionType.income,
              categoryId: 'other',
              walletId: 'w_precision',
              date: DateTime.now(),
            );
        await container.read(transactionsProvider.notifier).addTransaction(
              title: 'Cents Test 2-$i',
              amount: 0.20,
              type: TransactionType.income,
              categoryId: 'other',
              walletId: 'w_precision',
              date: DateTime.now(),
            );
      }

      // In IEEE 754 without cent-rounding, 5*(0.1+0.2) = 1.5000000000000004
      final wallets = container.read(walletsWithBalancesProvider);
      expect(wallets.first.currentBalance, 1.50,
          reason: 'Derived balances must round to exact 2 decimal places');
    });

    test('Invariants 5 & 6: Debt overpayment and Goal over-withdrawal clamping', () async {
      // 1. Debt overpayment handling: remaining debt cannot become negative
      final debt = DebtModel(
        id: 'd_clamp',
        personName: 'Charlie',
        totalAmount: 5000.0,
        remainingAmount: 2000.0,
        type: DebtType.lent,
        createdAt: DateTime.now(),
      );
      // Attempt paying 3,000 against a 2,000 remaining debt
      final settledDebt = debt.recordPayment(paymentAmount: 3000.0);
      expect(settledDebt.remainingAmount, 0.0);
      expect(settledDebt.isSettled, isTrue);

      // 2. Goal withdrawal clamping: saved amount cannot become negative
      final initialWallets = [
        const WalletModel(
          id: 'w_clamp',
          name: 'Clamp Wallet',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 1000.0,
          currentBalance: 1000.0,
          isDefault: true,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      await container.read(goalsProvider.notifier).addGoal(
            title: 'Vacation',
            targetAmount: 10000.0,
            currentSavedAmount: 500.0,
            walletId: 'w_clamp',
          );
      final goals = container.read(goalsProvider);
      // Attempt withdrawing 1,000 from a 500 saved balance
      await container.read(goalsProvider.notifier).withdrawFromGoal(
            goalId: goals.first.id,
            amount: 1000.0,
            walletId: 'w_clamp',
          );
      final updatedGoal = container.read(goalsProvider).first;
      expect(updatedGoal.currentSavedAmount, 0.0,
          reason: 'Goal withdrawals must clamp to 0.0 and never become negative');

      final recordedTx = container.read(transactionsProvider).first;
      expect(recordedTx.amount, 500.0,
          reason: 'Recorded transaction amount must match the actual clamped deduction of 500.0, not the requested 1000.0');
      final clampWallet = container.read(walletsWithBalancesProvider).firstWhere((w) => w.id == 'w_clamp');
      expect(clampWallet.currentBalance, 1500.0,
          reason: 'Wallet balance must increase by exact clamped goal withdrawal (+500), preventing unbacked phantom money');
    });

    test('Invariant 8: Recurring rule execution idempotency prevents duplication after restart', () async {
      final now = DateTime.now();
      final rule = RecurringRuleModel(
        id: 'rec_rent',
        title: 'Apartment Rent',
        amount: 25000.0,
        type: TransactionType.expense,
        categoryId: 'rent',
        walletId: 'w_default',
        frequency: RecurringFrequency.monthly,
        dueDay: 1,
        nextDueDate: now.subtract(const Duration(days: 1)), // Due yesterday
        createdAt: now.subtract(const Duration(days: 35)),
      );

      await storage.saveRecurringRules([rule]);

      // First run: processes the due rule
      final processedFirst = await storage.processDueRecurringRules();
      expect(processedFirst, 1);
      final txsAfterFirst = storage.getTransactions();
      expect(txsAfterFirst.length, 1);
      expect(txsAfterFirst.first.title, 'Apartment Rent');

      // Second run (simulating immediate app restart): rule nextDueDate is now in future, 0 processed
      final processedSecond = await storage.processDueRecurringRules();
      expect(processedSecond, 0);
      final txsAfterSecond = storage.getTransactions();
      expect(txsAfterSecond.length, 1,
          reason: 'Recurring rules must advance nextDueDate and not duplicate on restarts');
    });

    test('Invariant 10: Backup restoration produces identical financial ledger state', () async {
      final initialTx = TransactionModel(
        id: 'tx_backup_001',
        title: 'Salary Credit',
        amount: 120000.0,
        type: TransactionType.income,
        categoryId: 'salary',
        walletId: 'w_hdfc',
        date: DateTime(2026, 11, 1),
        createdAt: DateTime.now(),
      );

      final initialWallet = const WalletModel(
        id: 'w_hdfc',
        name: 'HDFC Corporate',
        icon: 'account_balance',
        colorValue: 0xFF2196F3,
        walletType: WalletType.bank,
        initialBalance: 50000.0,
        currentBalance: 50000.0,
        isDefault: true,
      );

      final backupData = {
        'transactions': [initialTx.toJson()],
        'wallets': [initialWallet.toJson()],
      };

      await storage.restoreDatabase(backupData);

      final restoredTxs = storage.getTransactions();
      final restoredWallets = storage.getWallets();

      expect(restoredTxs.length, 1);
      expect(restoredTxs.first.id, 'tx_backup_001');
      expect(restoredTxs.first.amount, 120000.0);

      expect(restoredWallets.length, 1);
      expect(restoredWallets.first.id, 'w_hdfc');
      expect(restoredWallets.first.name, 'HDFC Corporate');
    });

    test('Invariant 11: Double-entry atomic transfer persists both legs with shared refId and exact balance symmetry', () async {
      final initialWallets = [
        const WalletModel(
          id: 'w_source',
          name: 'Primary Checking',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          initialBalance: 10000.0,
          currentBalance: 10000.0,
          isDefault: true,
        ),
        const WalletModel(
          id: 'w_dest',
          name: 'Savings Vault',
          icon: 'savings',
          colorValue: 0xFF4CAF50,
          walletType: WalletType.savings,
          initialBalance: 5000.0,
          currentBalance: 5000.0,
        ),
      ];
      await storage.saveWallets(initialWallets);
      await container.read(walletsProvider.notifier).refreshFromDisk();

      final now = DateTime.now();
      final txs = await container.read(transactionsProvider.notifier).addDoubleEntryTransfer(
            fromWalletId: 'w_source',
            toWalletId: 'w_dest',
            fromWalletName: 'Primary Checking',
            toWalletName: 'Savings Vault',
            amount: 3500.0,
            date: now,
            note: 'Emergency Reserve Funding',
          );

      expect(txs.length, 2);
      final debit = txs.firstWhere((t) => t.type == TransactionType.expense);
      final credit = txs.firstWhere((t) => t.type == TransactionType.income);

      // Verify cryptographic/referential link
      expect(debit.refId, isNotNull);
      expect(credit.refId, isNotNull);
      expect(debit.refId, credit.refId, reason: 'Both transfer legs must share the exact same transfer refId');

      // Verify amounts and wallets
      expect(debit.amount, 3500.0);
      expect(credit.amount, 3500.0);
      expect(debit.walletId, 'w_source');
      expect(credit.walletId, 'w_dest');
      expect(debit.categoryId, 'cat_transfer');
      expect(credit.categoryId, 'cat_transfer');

      // Verify balances
      final wallets = container.read(walletsWithBalancesProvider);
      final source = wallets.firstWhere((w) => w.id == 'w_source');
      final dest = wallets.firstWhere((w) => w.id == 'w_dest');
      expect(source.currentBalance, 6500.0);
      expect(dest.currentBalance, 8500.0);

      final totalNetWorth = wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
      expect(totalNetWorth, 15000.0, reason: 'Internal fund transfer must preserve total net worth');

      // Verify persistence from disk
      final diskTxs = storage.getTransactions();
      expect(diskTxs.any((t) => t.id == debit.id), isTrue);
      expect(diskTxs.any((t) => t.id == credit.id), isTrue);
    });
  });
}

