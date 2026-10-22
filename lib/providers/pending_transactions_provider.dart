import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/pending_transaction_model.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'core_providers.dart';
import 'transactions_provider.dart';
import 'notifications_provider.dart';
import 'settings_provider.dart';
import 'wallets_provider.dart';

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

      // Check for two-way enrichment against existing saved transactions
      final savedTxs = _ref.read(transactionsProvider);
      final wallets = _ref.read(walletsProvider);
      for (final item in fetched) {
        final enriched = service.enrichSavedTransaction(item, savedTxs, wallets);
        if (enriched != null) {
          await _ref.read(transactionsProvider.notifier).updateTransaction(enriched);
        }
      }

      final current = List<PendingTransactionModel>.from(state);
      final merged = service.deduplicateAndAssignHeuristics([...current, ...fetched]);
      state = merged;

      // Auto-commit shared screenshots and auto-save items directly to database
      final settings = _ref.read(settingsProvider);
      final List<MapEntry<PendingTransactionModel, String?>> autoCommitItems = [];

      for (final item in merged) {
        final isSms = item.detectionSource == 'sms' || item.appSource.contains('SMS');
        if (isSms && (settings.autoSaveSms || (item.rawPayload != null && item.rawPayload!.contains('"autoSaveDirect":true')))) {
          // Strict user constraint: Only auto-log if explicit matching account digits or bank name found;
          // otherwise keep safely in Pending Review queue.
          final matchedWalletId = service.findExplicitMatchingWallet(item, wallets);
          if (matchedWalletId != null) {
            autoCommitItems.add(MapEntry(item, matchedWalletId));
          }
        } else if (item.detectionSource == 'screenshot' && settings.autoSaveScreenshots) {
          autoCommitItems.add(MapEntry(item, item.suggestedWalletId));
        }
      }

      for (final entry in autoCommitItems) {
        final item = entry.key;
        final targetWalletId = entry.value;
        await approve(item.id, walletId: targetWalletId);
        final isSms = item.detectionSource == 'sms' || item.appSource.contains('SMS');
        final title = isSms ? '💬 SMS Auto-Logged' : '📸 Receipt Auto-Logged';
        final matchedWallet = wallets.where((w) => w.id == targetWalletId).firstOrNull;
        final walletLabel = matchedWallet != null ? ' to ${matchedWallet.displayName}' : '';

        await _ref.read(notificationsProvider.notifier).addNotification(
          AppNotificationModel(
            id: const Uuid().v4(),
            title: title,
            message: '${item.merchant}: ${settings.currencySymbol}${item.amount.toStringAsFixed(2)} was automatically logged$walletLabel.',
            type: NotificationType.system,
            createdAt: DateTime.now(),
            actionData: {
              'amount': item.amount,
              'merchant': item.merchant,
              'refId': item.refId,
              'imagePath': item.imagePath,
              'walletId': targetWalletId,
            },
          ),
        );

        // Heads-up instant Android notification
        NotificationService().showTransactionLoggedNotification(
          title: item.merchant,
          amount: item.amount,
          currencySymbol: settings.currencySymbol,
          isIncome: item.isIncome,
          walletName: matchedWallet?.name,
        );
      }
    } catch (_) {
      // Non-blocking defensive catch
    }
  }

  /// Injects an unconfirmed transaction directly into the state (useful for simulated tests)
  void addPending(PendingTransactionModel item) {
    final service = _ref.read(autoImportServiceProvider);
    state = service.deduplicateAndAssignHeuristics([...state, item]);
  }

  /// Actively queries recent SMS from Android SMS provider to catch up on any messages
  /// that might have arrived while Pocket was sleeping or before permissions were granted.
  Future<void> syncRecentSmsInbox({int daysLookback = 2}) async {
    try {
      final service = _ref.read(autoImportServiceProvider);
      final recentSms = await service.scanSmsInbox(daysLookback: daysLookback);
      if (recentSms.isEmpty) return;

      final savedTxs = _ref.read(transactionsProvider);
      final newItems = recentSms.where((item) => !service.isAlreadySaved(item, savedTxs)).toList();
      if (newItems.isEmpty) return;

      final current = List<PendingTransactionModel>.from(state);
      final merged = service.deduplicateAndAssignHeuristics([...current, ...newItems]);
      state = merged;

      final settings = _ref.read(settingsProvider);
      final wallets = _ref.read(walletsProvider);
      final List<MapEntry<PendingTransactionModel, String?>> autoCommitItems = [];

      for (final item in merged) {
        final isSms = item.detectionSource == 'sms' || item.appSource.contains('SMS');
        if (isSms && (settings.autoSaveSms || (item.rawPayload != null && item.rawPayload!.contains('"autoSaveDirect":true')))) {
          final matchedWalletId = service.findExplicitMatchingWallet(item, wallets);
          if (matchedWalletId != null) {
            autoCommitItems.add(MapEntry(item, matchedWalletId));
          }
        }
      }

      for (final entry in autoCommitItems) {
        final item = entry.key;
        final targetWalletId = entry.value;
        await approve(item.id, walletId: targetWalletId);
        final title = '💬 SMS Auto-Logged';
        final matchedWallet = wallets.where((w) => w.id == targetWalletId).firstOrNull;
        final walletLabel = matchedWallet != null ? ' to ${matchedWallet.displayName}' : '';

        await _ref.read(notificationsProvider.notifier).addNotification(
          AppNotificationModel(
            id: const Uuid().v4(),
            title: title,
            message: '${item.merchant}: ${settings.currencySymbol}${item.amount.toStringAsFixed(2)} was automatically logged$walletLabel.',
            type: NotificationType.system,
            createdAt: DateTime.now(),
            actionData: {
              'amount': item.amount,
              'merchant': item.merchant,
              'refId': item.refId,
              'imagePath': item.imagePath,
              'walletId': targetWalletId,
            },
          ),
        );

        NotificationService().showTransactionLoggedNotification(
          title: item.merchant,
          amount: item.amount,
          currencySymbol: settings.currencySymbol,
          isIncome: item.isIncome,
          walletName: matchedWallet?.name,
        );
      }
    } catch (_) {}
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
    final wallets = _ref.read(walletsProvider);
    final fallbackWalletId = wallets.isNotEmpty
        ? (wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first).id)
        : 'cash';
    final effectiveWalletId = (walletId != null && wallets.any((w) => w.id == walletId))
        ? walletId
        : ((item.suggestedWalletId != null && wallets.any((w) => w.id == item.suggestedWalletId))
            ? item.suggestedWalletId!
            : fallbackWalletId);
    final effectiveCategoryId = categoryId ?? item.suggestedCategoryId ?? (item.isIncome ? 'salary' : 'food');

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
      counterpartyLast4: item.counterpartyLast4,
      appSource: item.appSource,
      rawPayload: item.rawPayload,
      receiptImagePath: item.imagePath,
    );

    state = state.where((p) => p.id != id).toList();
  }

  /// Batch-commits all currently pending transactions into the database
  Future<int> approveAll() async {
    final items = List<PendingTransactionModel>.from(state);
    if (items.isEmpty) return 0;

    final wallets = _ref.read(walletsProvider);
    final fallbackWalletId = wallets.isNotEmpty
        ? (wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first).id)
        : 'cash';

    int approved = 0;
    for (final item in items) {
      final effectiveWalletId = (item.suggestedWalletId != null && wallets.any((w) => w.id == item.suggestedWalletId))
          ? item.suggestedWalletId!
          : fallbackWalletId;
      final effectiveCategoryId = item.suggestedCategoryId ?? (item.isIncome ? 'salary' : 'food');

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
        counterpartyLast4: item.counterpartyLast4,
        appSource: item.appSource,
        rawPayload: item.rawPayload,
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
