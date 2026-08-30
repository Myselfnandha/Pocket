import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/category_model.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'core_providers.dart';
import 'settings_provider.dart';
import 'transactions_provider.dart';

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

    if (dueDate != null) {
      final settings = _ref.read(settingsProvider);
      await NotificationService().scheduleDebtReminder(
        debtId: newDebt.id,
        personName: newDebt.personName,
        amount: newDebt.remainingAmount,
        currencySymbol: settings.currencySymbol,
        isLent: newDebt.type == DebtType.lent,
        dueDate: dueDate,
      );
    }

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

    if (updatedDebt.isSettled) {
      await NotificationService().cancelDebtReminder(debtId);
    }

    if (updateWallet && walletId != null) {
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
    await NotificationService().cancelDebtReminder(id);
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
