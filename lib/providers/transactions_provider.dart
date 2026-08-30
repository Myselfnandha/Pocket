import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/storage_service.dart';
import 'core_providers.dart';

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final StorageService _storage;

  TransactionsNotifier(this._storage) : super(_storage.getTransactions());

  Future<TransactionModel> addTransaction({
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
    List<String> tags = const [],
    List<String> attachments = const [],
  }) async {
    final effectiveAttachments = [
      ...attachments,
      if (receiptImagePath != null && !attachments.contains(receiptImagePath)) receiptImagePath,
    ];

    final newTx = TransactionModel(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      date: date,
      note: note,
      receiptImagePath: receiptImagePath ?? (effectiveAttachments.isNotEmpty ? effectiveAttachments.first : null),
      senderName: senderName,
      receiverName: receiverName,
      refId: refId,
      counterpartyLast4: counterpartyLast4,
      tags: tags,
      attachments: effectiveAttachments,
      createdAt: DateTime.now(),
    );

    state = [newTx, ...state];
    await _storage.saveTransactions(state);
    return newTx;
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    state = [
      for (final item in state)
        if (item.id == tx.id) tx else item,
    ];
    await _storage.saveTransactions(state);
  }

  Future<void> insertTransactionAt(int index, TransactionModel tx) async {
    final list = List<TransactionModel>.from(state);
    final safeIndex = index.clamp(0, list.length);
    list.insert(safeIndex, tx);
    state = list;
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

/// Unique list of all tags currently in use across transactions
final allTagsProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final Set<String> tagSet = {};
  for (final tx in txs) {
    for (final tag in tx.tags) {
      if (tag.trim().isNotEmpty) {
        tagSet.add(tag.trim());
      }
    }
  }
  return tagSet.toList()..sort();
});
