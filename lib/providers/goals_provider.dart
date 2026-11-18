import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/goal_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';

class GoalsNotifier extends StateNotifier<List<GoalModel>> {
  final StorageService _storage;
  final Ref _ref;

  GoalsNotifier(this._storage, this._ref) : super(_storage.getGoals());

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    double currentSavedAmount = 0.0,
    DateTime? targetDate,
    String? walletId,
    String emojiIcon = '🎯',
    int colorValue = 0xFF00E676,
  }) async {
    final now = DateTime.now();
    final newGoal = GoalModel(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'My Goal' : title.trim(),
      targetAmount: targetAmount,
      currentSavedAmount: currentSavedAmount,
      targetDate: targetDate,
      walletId: walletId,
      emojiIcon: emojiIcon,
      colorValue: colorValue,
      createdAt: now,
    );

    state = [newGoal, ...state];
    await _storage.saveGoals(state);
  }

  Future<void> updateGoal(GoalModel goal) async {
    state = [
      for (final g in state)
        if (g.id == goal.id) goal else g,
    ];
    await _storage.saveGoals(state);
  }

  Future<void> depositToGoal({
    required String goalId,
    required double amount,
    required String walletId,
    String? note,
  }) async {
    final cleanAmount = (amount.abs() * 100).round() / 100.0;
    if (cleanAmount <= 0) return;

    final goal = state.firstWhere((g) => g.id == goalId);
    final updated = goal.copyWith(
      currentSavedAmount: ((goal.currentSavedAmount + cleanAmount) * 100).round() / 100.0,
    );

    state = [
      for (final g in state)
        if (g.id == goalId) updated else g,
    ];
    await _storage.saveGoals(state);

    // Record saving transaction as deduction from wallet
    await _ref.read(transactionsProvider.notifier).addTransaction(
          title: 'Deposit to ${goal.title}',
          amount: cleanAmount,
          type: TransactionType.expense,
          categoryId: 'savings',
          walletId: walletId,
          date: DateTime.now(),
          note: note ?? 'Added savings toward goal ${goal.title}',
        );
  }

  Future<void> withdrawFromGoal({
    required String goalId,
    required double amount,
    required String walletId,
    String? note,
  }) async {
    final cleanAmount = (amount.abs() * 100).round() / 100.0;
    if (cleanAmount <= 0) return;

    final goal = state.firstWhere((g) => g.id == goalId);
    // Financial invariant: cannot withdraw more than currently saved in this goal
    final effectiveDeduction = cleanAmount > goal.currentSavedAmount
        ? goal.currentSavedAmount
        : cleanAmount;
    if (effectiveDeduction <= 0) return;

    final updatedAmount = ((goal.currentSavedAmount - effectiveDeduction) * 100).round() / 100.0;
    final updated = goal.copyWith(currentSavedAmount: updatedAmount);

    state = [
      for (final g in state)
        if (g.id == goalId) updated else g,
    ];
    await _storage.saveGoals(state);

    // Record withdrawal transaction as credit into wallet matching the exact deducted amount
    await _ref.read(transactionsProvider.notifier).addTransaction(
          title: 'Withdrawal from ${goal.title}',
          amount: effectiveDeduction,
          type: TransactionType.income,
          categoryId: 'savings',
          walletId: walletId,
          date: DateTime.now(),
          note: note ?? 'Withdrawn from savings goal ${goal.title}',
        );
  }

  Future<void> deleteGoal(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _storage.saveGoals(state);
  }

  Future<void> refreshFromDisk() async {
    await _storage.reload();
    state = _storage.getGoals();
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, List<GoalModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return GoalsNotifier(storage, ref);
});

final totalSavedInGoalsProvider = Provider<double>((ref) {
  final goals = ref.watch(goalsProvider);
  return goals.fold(0.0, (sum, g) => sum + g.currentSavedAmount);
});

final activeGoalsCountProvider = Provider<int>((ref) {
  final goals = ref.watch(goalsProvider);
  return goals.where((g) => !g.isCompleted).length;
});
