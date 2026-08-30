import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';

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

/// Map of categoryId -> total expense for previous month
final lastMonthCategorySpendingProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1, 1);
  final Map<String, double> spending = {};

  for (final tx in txs) {
    if (tx.type == TransactionType.expense &&
        tx.date.year == lastMonth.year &&
        tx.date.month == lastMonth.month) {
      spending[tx.categoryId] = (spending[tx.categoryId] ?? 0.0) + tx.amount;
    }
  }

  return spending;
});

/// Map of categoryId -> effective budget limit with rollover applied
final effectiveCategoryBudgetsProvider = Provider<Map<String, double>>((ref) {
  final budgets = ref.watch(categoryBudgetsProvider);
  final lastMonthSpending = ref.watch(lastMonthCategorySpendingProvider);
  final Map<String, double> effective = {};

  for (final b in budgets) {
    final lastSpent = lastMonthSpending[b.categoryId] ?? 0.0;
    effective[b.categoryId] = b.calculateEffectiveLimit(lastMonthSpent: lastSpent);
  }

  return effective;
});

/// Total monthly budget limit across all configured categories (including rollover)
final totalCategoryBudgetLimitProvider = Provider<double>((ref) {
  final effectiveBudgets = ref.watch(effectiveCategoryBudgetsProvider);
  if (effectiveBudgets.isNotEmpty) {
    return effectiveBudgets.values.fold(0.0, (sum, val) => sum + val);
  }
  final budgets = ref.watch(categoryBudgetsProvider);
  return budgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
});

