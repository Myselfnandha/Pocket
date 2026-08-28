import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main()');
});

// --- Settings Provider ---

class SettingsNotifier extends StateNotifier<UserSettingsModel> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.getSettings());

  Future<void> updateSettings(UserSettingsModel newSettings) async {
    state = newSettings;
    await _storage.saveSettings(newSettings);
  }

  Future<void> setThemePreference(AppThemePreference pref) async {
    await updateSettings(state.copyWith(themePreference: pref));
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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettingsModel>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

// --- Theme Mode Calculation ---

final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.themePreference) {
    case AppThemePreference.darkAmoled:
      return ThemeMode.dark;
    case AppThemePreference.light:
      return ThemeMode.light;
    case AppThemePreference.autoTime:
      final hour = DateTime.now().hour;
      // Dark between 6 PM (18) and 6 AM (6)
      if (hour >= 18 || hour < 6) {
        return ThemeMode.dark;
      }
      return ThemeMode.light;
  }
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
