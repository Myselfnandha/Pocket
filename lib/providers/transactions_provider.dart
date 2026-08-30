import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final StorageService _storage;

  TransactionsNotifier(this._storage) : super(_storage.getTransactions());

  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String walletId,
    required DateTime date,
    String? note,
    String? receiptImagePath,
    String? senderName,
    String? receiverName,
    String? refId,
    String? counterpartyLast4,
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
      senderName: senderName,
      receiverName: receiverName,
      refId: refId,
      counterpartyLast4: counterpartyLast4,
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

  Future<void> refreshFromDisk() async {
    await _storage.reload();
    state = _storage.getTransactions();
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TransactionsNotifier(storage);
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
