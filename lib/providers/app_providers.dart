import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/recurring_model.dart';
import '../models/notification_model.dart';
import '../models/debt_model.dart';
import '../models/budget_model.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main()');
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BackupService(storage);
});

// --- Settings Provider ---

class SettingsNotifier extends StateNotifier<UserSettingsModel> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.getSettings());

  Future<void> updateSettings(UserSettingsModel newSettings) async {
    state = newSettings;
    await _storage.saveSettings(newSettings);

    // Update scheduled daily reminder if changed
    await NotificationService().scheduleDailyReminder(
      hour: newSettings.dailyReminderHour,
      minute: newSettings.dailyReminderMinute,
      enabled: newSettings.dailyReminderEnabled,
    );
  }

  Future<void> setCurrency(String symbol, String code) async {
    await updateSettings(
      state.copyWith(currencySymbol: symbol, currencyCode: code),
    );
  }

  Future<void> setUserName(String name) async {
    await updateSettings(state.copyWith(userName: name));
  }

  Future<void> completeOnboarding() async {
    await updateSettings(state.copyWith(isOnboarded: true));
  }

  Future<void> toggleCategoryTags(bool value) async {
    await updateSettings(state.copyWith(showCategoryTags: value));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettingsModel>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

// --- Theme Mode & Data Calculation ---

final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.themeMode == AppThemeMode.autoTime) {
    final hour = DateTime.now().hour;
    if (hour >= 18 || hour < 6) {
      return ThemeMode.dark;
    }
    return ThemeMode.light;
  }

  switch (settings.manualThemeStyle) {
    case ManualThemeStyle.light:
      return ThemeMode.light;
    case ManualThemeStyle.dark:
    case ManualThemeStyle.pureBlack:
      return ThemeMode.dark;
  }
});

final activeDarkThemeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  final isAmoled = settings.isPureBlackEnabled ||
      (settings.themeMode == AppThemeMode.manual &&
          settings.manualThemeStyle == ManualThemeStyle.pureBlack);
  return AppTheme.getDarkTheme(isPureBlack: isAmoled);
});

// --- Categories Provider ---

class CategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  final StorageService _storage;

  CategoriesNotifier(this._storage) : super(_storage.getCategories());

  Future<void> addCategory(CategoryModel category) async {
    state = [...state, category];
    await _storage.saveCategories(state);
  }

  Future<void> updateCategory(CategoryModel category) async {
    state = [
      for (final cat in state)
        if (cat.id == category.id) category else cat,
    ];
    await _storage.saveCategories(state);
  }

  Future<void> deleteCategory(String id) async {
    state = state.where((cat) => cat.id != id).toList();
    await _storage.saveCategories(state);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<CategoryModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return CategoriesNotifier(storage);
});

// --- Wallets Provider ---

class WalletsNotifier extends StateNotifier<List<WalletModel>> {
  final StorageService _storage;

  WalletsNotifier(this._storage) : super(_storage.getWallets());

  Future<void> addWallet(WalletModel wallet) async {
    state = [...state, wallet];
    await _storage.saveWallets(state);
  }

  Future<void> updateWallet(WalletModel wallet) async {
    state = [
      for (final w in state)
        if (w.id == wallet.id) wallet else w,
    ];
    await _storage.saveWallets(state);
  }

  Future<void> deleteWallet(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _storage.saveWallets(state);
  }
}

final walletsProvider =
    StateNotifierProvider<WalletsNotifier, List<WalletModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return WalletsNotifier(storage);
});

// Purely reactive wallets with real-time balance calculations
final walletsWithBalancesProvider = Provider<List<WalletModel>>((ref) {
  final wallets = ref.watch(walletsProvider);
  final txs = ref.watch(transactionsProvider);

  return wallets.map((wallet) {
    double balance = wallet.initialBalance;
    for (final tx in txs) {
      if (tx.walletId == wallet.id) {
        if (tx.type == TransactionType.income) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }
    }
    return wallet.copyWith(currentBalance: balance);
  }).toList();
});

// --- Transactions Provider ---

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final StorageService _storage;

  TransactionsNotifier(this._storage)
      : super(_storage.getTransactions());

  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String walletId,
    required DateTime date,
    String? note,
    String? receiptImagePath,
  }) async {
    final newTx = TransactionModel(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      date: date,
      note: note,
      receiptImagePath: receiptImagePath,
      createdAt: DateTime.now(),
    );

    state = [newTx, ...state];
    await _storage.saveTransactions(state);
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    state = [
      for (final item in state)
        if (item.id == tx.id) tx else item,
    ];
    await _storage.saveTransactions(state);
  }

  Future<void> deleteTransaction(String id) async {
    state = state.where((tx) => tx.id != id).toList();
    await _storage.saveTransactions(state);
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TransactionsNotifier(storage);
});

// --- Recurring Rules Provider ---

class RecurringRulesNotifier extends StateNotifier<List<RecurringRuleModel>> {
  final StorageService _storage;

  RecurringRulesNotifier(this._storage) : super(_storage.getRecurringRules());

  Future<void> addRule(RecurringRuleModel rule) async {
    state = [...state, rule];
    await _storage.saveRecurringRules(state);
  }

  Future<void> updateRule(RecurringRuleModel rule) async {
    state = [
      for (final r in state)
        if (r.id == rule.id) rule else r,
    ];
    await _storage.saveRecurringRules(state);
  }

  Future<void> toggleRuleActive(String id) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isActive: !r.isActive) else r,
    ];
    await _storage.saveRecurringRules(state);
  }

  Future<void> deleteRule(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _storage.saveRecurringRules(state);
  }

  Future<int> processDueRules() async {
    final generatedCount = await _storage.processDueRecurringRules();
    if (generatedCount > 0) {
      state = _storage.getRecurringRules();
    }
    return generatedCount;
  }
}

final recurringRulesProvider =
    StateNotifierProvider<RecurringRulesNotifier, List<RecurringRuleModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecurringRulesNotifier(storage);
});

// --- In-App Notifications Provider ---

class NotificationsNotifier extends StateNotifier<List<AppNotificationModel>> {
  final StorageService _storage;

  NotificationsNotifier(this._storage) : super(_storage.getNotifications());

  Future<void> addNotification(AppNotificationModel notif) async {
    state = [notif, ...state];
    await _storage.saveNotifications(state);
  }

  Future<void> markAsRead(String id) async {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _storage.saveNotifications(state);
  }

  Future<void> markAllAsRead() async {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    await _storage.saveNotifications(state);
  }

  Future<void> clearAll() async {
    state = [];
    await _storage.saveNotifications([]);
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotificationModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationsNotifier(storage);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});

// --- Debts & Loans Provider ---

class DebtsNotifier extends StateNotifier<List<DebtModel>> {
  final StorageService _storage;
  final Ref _ref;

  DebtsNotifier(this._storage, this._ref) : super(_storage.getDebts());

  Future<void> addDebt({
    required String personName,
    String? phoneNumber,
    required double amount,
    required DebtType type,
    DateTime? dueDate,
    String? walletId,
    String? notes,
    bool updateWallet = false,
  }) async {
    final now = DateTime.now();
    final newDebt = DebtModel(
      id: const Uuid().v4(),
      personName: personName.trim(),
      phoneNumber: phoneNumber?.trim(),
      totalAmount: amount,
      remainingAmount: amount,
      type: type,
      dueDate: dueDate,
      walletId: walletId,
      notes: notes,
      createdAt: now,
    );

    state = [newDebt, ...state];
    await _storage.saveDebts(state);

    // If updateWallet is true:
    // Lent -> Expense from wallet
    // Borrowed -> Income to wallet
    if (updateWallet && walletId != null) {
      await _ref.read(transactionsProvider.notifier).addTransaction(
            title: type == DebtType.lent ? 'Lent to $personName' : 'Borrowed from $personName',
            amount: amount,
            type: type == DebtType.lent ? TransactionType.expense : TransactionType.income,
            categoryId: 'other',
            walletId: walletId,
            date: now,
            note: notes,
          );
    }
  }

  Future<void> recordPayment({
    required String debtId,
    required double amount,
    String? note,
    String? walletId,
    bool updateWallet = true,
  }) async {
    final debt = state.firstWhere((d) => d.id == debtId);
    final updatedDebt = debt.recordPayment(
      paymentAmount: amount,
      note: note,
      walletId: walletId,
    );

    state = [
      for (final d in state)
        if (d.id == debtId) updatedDebt else d,
    ];
    await _storage.saveDebts(state);

    if (updateWallet && walletId != null) {
      // Repayment of Lent money -> Income into wallet
      // Repayment of Borrowed money -> Expense out of wallet
      await _ref.read(transactionsProvider.notifier).addTransaction(
            title: debt.type == DebtType.lent ? 'Repayment from ${debt.personName}' : 'Repaid to ${debt.personName}',
            amount: amount,
            type: debt.type == DebtType.lent ? TransactionType.income : TransactionType.expense,
            categoryId: 'other',
            walletId: walletId,
            date: DateTime.now(),
            note: note,
          );
    }
  }

  Future<void> settleDebt({
    required String debtId,
    String? walletId,
    bool updateWallet = true,
  }) async {
    final debt = state.firstWhere((d) => d.id == debtId);
    if (debt.remainingAmount <= 0) return;

    await recordPayment(
      debtId: debtId,
      amount: debt.remainingAmount,
      note: 'Full settlement',
      walletId: walletId,
      updateWallet: updateWallet,
    );
  }

  Future<void> deleteDebt(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _storage.saveDebts(state);
  }
}

final debtsProvider =
    StateNotifierProvider<DebtsNotifier, List<DebtModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DebtsNotifier(storage, ref);
});

final totalLentProvider = Provider<double>((ref) {
  final debts = ref.watch(debtsProvider);
  return debts
      .where((d) => d.type == DebtType.lent && !d.isSettled)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);
});

final totalBorrowedProvider = Provider<double>((ref) {
  final debts = ref.watch(debtsProvider);
  return debts
      .where((d) => d.type == DebtType.borrowed && !d.isSettled)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);
});

// --- Derived Stats & Selectors ---

final totalBalanceProvider = Provider<double>((ref) {
  final wallets = ref.watch(walletsWithBalancesProvider);
  return wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
});

final todayTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();
  return txs.where((t) {
    return t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day;
  }).toList();
});

class MonthlyStats {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate;
  final double todayExpense;

  const MonthlyStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.todayExpense,
  });
}

final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();

  double income = 0;
  double expense = 0;
  double todayExp = 0;

  for (final tx in txs) {
    if (tx.date.year == now.year && tx.date.month == now.month) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
        if (tx.date.day == now.day) {
          todayExp += tx.amount;
        }
      }
    }
  }

  final net = income - expense;
  final rate = income > 0 ? (net / income * 100).clamp(0.0, 100.0) : 0.0;

  return MonthlyStats(
    totalIncome: income,
    totalExpense: expense,
    netSavings: net,
    savingsRate: rate,
    todayExpense: todayExp,
  );
});

// --- Category Budgets & Spending Caps Provider ---

class CategoryBudgetsNotifier extends StateNotifier<List<CategoryBudgetModel>> {
  final StorageService _storage;

  CategoryBudgetsNotifier(this._storage) : super(_storage.getCategoryBudgets());

  Future<void> setBudget({
    required String categoryId,
    required double monthlyLimit,
    bool isRolloverEnabled = false,
  }) async {
    final now = DateTime.now();
    final existingIndex = state.indexWhere((b) => b.categoryId == categoryId);

    if (existingIndex >= 0) {
      final updated = state[existingIndex].copyWith(
        monthlyLimit: monthlyLimit,
        isRolloverEnabled: isRolloverEnabled,
        updatedAt: now,
      );
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) updated else state[i],
      ];
    } else {
      final newBudget = CategoryBudgetModel(
        id: const Uuid().v4(),
        categoryId: categoryId,
        monthlyLimit: monthlyLimit,
        isRolloverEnabled: isRolloverEnabled,
        createdAt: now,
        updatedAt: now,
      );
      state = [...state, newBudget];
    }

    await _storage.saveCategoryBudgets(state);
  }

  Future<void> deleteBudget(String budgetId) async {
    state = state.where((b) => b.id != budgetId).toList();
    await _storage.saveCategoryBudgets(state);
  }

  Future<void> deleteBudgetByCategoryId(String categoryId) async {
    state = state.where((b) => b.categoryId != categoryId).toList();
    await _storage.saveCategoryBudgets(state);
  }
}

final categoryBudgetsProvider =
    StateNotifierProvider<CategoryBudgetsNotifier, List<CategoryBudgetModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return CategoryBudgetsNotifier(storage);
});

/// Map of categoryId -> total expense for current month
final currentMonthCategorySpendingProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();
  final Map<String, double> spending = {};

  for (final tx in txs) {
    if (tx.type == TransactionType.expense &&
        tx.date.year == now.year &&
        tx.date.month == now.month) {
      spending[tx.categoryId] = (spending[tx.categoryId] ?? 0.0) + tx.amount;
    }
  }

  return spending;
});

/// Total monthly budget limit across all configured categories
final totalCategoryBudgetLimitProvider = Provider<double>((ref) {
  final budgets = ref.watch(categoryBudgetsProvider);
  return budgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
});

