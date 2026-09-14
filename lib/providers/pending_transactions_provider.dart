import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/pending_transaction_model.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';

final pendingTransactionsProvider =
    StateNotifierProvider<PendingTransactionsNotifier, List<PendingTransactionModel>>((ref) {
  return PendingTransactionsNotifier(ref);
});

class PendingTransactionsNotifier extends StateNotifier<List<PendingTransactionModel>> {
  final Ref _ref;

  PendingTransactionsNotifier(this._ref) : super([]) {
    fetchPendingTransactions();
  }

  /// Polls the native Android buffer for newly intercepted notifications/screens/screenshots
  Future<void> fetchPendingTransactions() async {
    try {
      final service = _ref.read(autoImportServiceProvider);
      final fetched = await service.fetchAndDrainPendingTransactions();
      if (fetched.isEmpty) return;

      final current = List<PendingTransactionModel>.from(state);
      final merged = service.deduplicateAndAssignHeuristics([...current, ...fetched]);
      state = merged;
    } catch (_) {
      // Non-blocking defensive catch
    }
  }

  /// Injects an unconfirmed transaction directly into the state (useful for simulated tests)
  void addPending(PendingTransactionModel item) {
    final service = _ref.read(autoImportServiceProvider);
    state = service.deduplicateAndAssignHeuristics([...state, item]);
  }

  /// Approves a single detected transaction and commits it into Pocket's permanent database
  Future<void> approve(
    String id, {
    String? title,
    String? categoryId,
    String? walletId,
    String? note,
  }) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final item = state[index];
    final effectiveWalletId = walletId ?? item.suggestedWalletId ?? 'default_cash';
    final effectiveCategoryId = categoryId ?? item.suggestedCategoryId ?? 'food';

    final effectiveNote = note ??
        (item.refId != null && item.refId!.isNotEmpty
            ? 'Ref: ${item.refId}'
            : (item.appSource.isNotEmpty ? 'Imported via ${item.appSource}' : null));

    await _ref.read(transactionsProvider.notifier).addTransaction(
      title: (title != null && title.trim().isNotEmpty) ? title.trim() : item.merchant,
      amount: item.amount,
      type: item.isIncome ? TransactionType.income : TransactionType.expense,
      categoryId: effectiveCategoryId,
      walletId: effectiveWalletId,
      date: item.date,
      note: effectiveNote,
      refId: item.refId,
      receiptImagePath: item.imagePath,
    );

    state = state.where((p) => p.id != id).toList();
  }

  /// Batch-commits all currently pending transactions into the database
  Future<int> approveAll() async {
    final items = List<PendingTransactionModel>.from(state);
    if (items.isEmpty) return 0;

    int approved = 0;
    for (final item in items) {
      final effectiveWalletId = item.suggestedWalletId ?? 'default_cash';
      final effectiveCategoryId = item.suggestedCategoryId ?? 'food';

      await _ref.read(transactionsProvider.notifier).addTransaction(
        title: item.merchant,
        amount: item.amount,
        type: item.isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: effectiveCategoryId,
        walletId: effectiveWalletId,
        date: item.date,
        note: (item.refId != null && item.refId!.isNotEmpty)
            ? 'Ref: ${item.refId}'
            : 'Imported via ${item.appSource}',
        refId: item.refId,
        receiptImagePath: item.imagePath,
      );
      approved++;
    }

    state = [];
    return approved;
  }

  /// Dismisses a pending transaction without saving it
  void dismiss(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  /// Dismisses all pending transactions
  void dismissAll() {
    state = [];
  }
}
