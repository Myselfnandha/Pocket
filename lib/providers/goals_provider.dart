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
    final goal = state.firstWhere((g) => g.id == goalId);
    final updated = goal.copyWith(
      currentSavedAmount: goal.currentSavedAmount + amount,
    );

    state = [
      for (final g in state)
        if (g.id == goalId) updated else g,
    ];
    await _storage.saveGoals(state);

    // Record saving transaction as deduction from wallet
    await _ref.read(transactionsProvider.notifier).addTransaction(
          title: 'Deposit to ${goal.title}',
          amount: amount,
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
    final goal = state.firstWhere((g) => g.id == goalId);
    final updatedAmount = (goal.currentSavedAmount - amount).clamp(0.0, double.infinity);
    final updated = goal.copyWith(currentSavedAmount: updatedAmount);

    state = [
      for (final g in state)
        if (g.id == goalId) updated else g,
    ];
    await _storage.saveGoals(state);

    // Record withdrawal transaction as credit into wallet
    await _ref.read(transactionsProvider.notifier).addTransaction(
          title: 'Withdrawal from ${goal.title}',
          amount: amount,
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
