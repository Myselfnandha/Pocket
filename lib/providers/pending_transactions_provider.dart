import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/pending_transaction_model.dart';
import '../models/notification_model.dart';
import '../models/wallet_model.dart';
import '../services/bank_discovery_service.dart';
import '../services/notification_service.dart';
import '../services/system_widget_service.dart';
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
  bool _isSyncingSms = false;

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

      // Auto-commit live incoming items directly to database when explicitly configured
      final settings = _ref.read(settingsProvider);
      final List<MapEntry<PendingTransactionModel, String?>> autoCommitItems = [];

      for (final item in merged) {
        final isPaytm = item.appSource.toLowerCase().contains('paytm') ||
            (item.rawPayload != null && item.rawPayload!.toLowerCase().contains('paytm'));
        final isAutoDirect = item.autoSaveDirect ||
            (item.rawPayload != null && item.rawPayload!.contains('"autoSaveDirect":true'));
        final isSms = item.detectionSource == 'sms' || item.appSource.contains('SMS');

        if (isPaytm || (isSms && settings.autoSaveSms) || (isAutoDirect && settings.autoSaveSms)) {
          var matchedWalletId = service.findExplicitMatchingWallet(item, wallets);
          if (matchedWalletId == null && wallets.isNotEmpty) {
            final upiOrPaytm = wallets.where((w) =>
                w.walletType == WalletType.upi ||
                w.name.toLowerCase().contains('paytm') ||
                w.name.toLowerCase().contains('upi')).firstOrNull;
            matchedWalletId = upiOrPaytm?.id ?? service.matchWallet(item, wallets);
          }
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
        final isPaytm = item.appSource.toLowerCase().contains('paytm') ||
            (item.rawPayload != null && item.rawPayload!.toLowerCase().contains('paytm'));
        final title = isPaytm ? '📱 Paytm Auto-Logged' : (isSms ? '💬 SMS Auto-Logged' : '📸 Receipt Auto-Logged');
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

      if (autoCommitItems.isNotEmpty) {
        final storage = _ref.read(storageServiceProvider);
        await SystemWidgetService.syncFromStorage(storage);
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
  /// Uses a durable timestamp checkpoint with 1-hour overlap and concurrency mutex.
  Future<void> syncRecentSmsInbox({int daysLookback = 2}) async {
    if (_isSyncingSms) return;
    _isSyncingSms = true;

    try {
      final storage = _ref.read(storageServiceProvider);
      final service = _ref.read(autoImportServiceProvider);
      final now = DateTime.now().millisecondsSinceEpoch;

      final recentSms = await service.scanSmsInbox(daysLookback: daysLookback);
      await storage.setLastSmsScanTimestamp(now);

      if (recentSms.isEmpty) return;

      final savedTxs = _ref.read(transactionsProvider);
      final newItems = recentSms.where((item) => !service.isAlreadySaved(item, savedTxs)).toList();
      if (newItems.isEmpty) return;

      final current = List<PendingTransactionModel>.from(state);
      final merged = service.deduplicateAndAssignHeuristics([...current, ...newItems]);
      state = merged;

      // Auto-commit newly synced SMS directly to database without manual review when autoSaveSms is enabled
      final settings = _ref.read(settingsProvider);
      if (settings.autoSaveSms) {
        for (final item in newItems) {
          await approve(item.id);
        }
      }
    } catch (_) {
      // Defensive handling
    } finally {
      _isSyncingSms = false;
    }
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
    final storage = _ref.read(storageServiceProvider);
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

    if (item.sourceMessageId != null) {
      await storage.addProcessedMessageId(item.sourceMessageId!);
    }
    await storage.removeDeletedTransactionSignature(item.signature);

    // If SMS contains fresh available balance, advance wallet snapshot baseline
    final extractedBal = BankDiscoveryService.extractAvailableBalance(item.rawPayload);
    if (extractedBal != null) {
      final targetWallet = wallets.where((w) => w.id == effectiveWalletId).firstOrNull;
      if (targetWallet != null) {
        final isFresher = targetWallet.balanceSnapshotAt == null ||
            item.date.isAfter(targetWallet.balanceSnapshotAt!) ||
            item.date.isAtSameMomentAs(targetWallet.balanceSnapshotAt!);
        if (isFresher) {
          await _ref.read(walletsProvider.notifier).updateWallet(
                targetWallet.copyWith(
                  initialBalance: extractedBal,
                  currentBalance: extractedBal,
                  balanceSnapshotAt: item.date,
                ),
              );
        }
      }
    }

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
      senderBank: item.senderBank,
      senderName: item.senderName,
      receiverName: item.receiverName,
      linkedContactName: item.linkedContactName,
      linkedContactPhone: item.linkedContactPhone,
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
    final storage = _ref.read(storageServiceProvider);
    final fallbackWalletId = wallets.isNotEmpty
        ? (wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first).id)
        : 'cash';

    int approved = 0;
    final Map<String, (double, DateTime)> freshestBalancesPerWallet = {};

    for (final item in items) {
      final effectiveWalletId = (item.suggestedWalletId != null && wallets.any((w) => w.id == item.suggestedWalletId))
          ? item.suggestedWalletId!
          : fallbackWalletId;
      final effectiveCategoryId = item.suggestedCategoryId ?? (item.isIncome ? 'salary' : 'food');

      // Check for available balance in raw payload
      final extractedBal = BankDiscoveryService.extractAvailableBalance(item.rawPayload);
      if (extractedBal != null) {
        final existingFreshest = freshestBalancesPerWallet[effectiveWalletId];
        if (existingFreshest == null || item.date.isAfter(existingFreshest.$2)) {
          freshestBalancesPerWallet[effectiveWalletId] = (extractedBal, item.date);
        }
      }

      if (item.sourceMessageId != null) {
        await storage.addProcessedMessageId(item.sourceMessageId!);
      }
      await storage.removeDeletedTransactionSignature(item.signature);

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
        senderBank: item.senderBank,
        senderName: item.senderName,
        receiverName: item.receiverName,
        linkedContactName: item.linkedContactName,
        linkedContactPhone: item.linkedContactPhone,
        appSource: item.appSource,
        rawPayload: item.rawPayload,
        receiptImagePath: item.imagePath,
      );
      approved++;
    }

    if (freshestBalancesPerWallet.isNotEmpty) {
      for (final entry in freshestBalancesPerWallet.entries) {
        final walletId = entry.key;
        final (newBal, snapshotDate) = entry.value;
        final targetWallet = wallets.where((w) => w.id == walletId).firstOrNull;
        if (targetWallet != null) {
          final isFresher = targetWallet.balanceSnapshotAt == null ||
              snapshotDate.isAfter(targetWallet.balanceSnapshotAt!) ||
              snapshotDate.isAtSameMomentAs(targetWallet.balanceSnapshotAt!);
          if (isFresher) {
            await _ref.read(walletsProvider.notifier).updateWallet(
                  targetWallet.copyWith(
                    initialBalance: newBal,
                    currentBalance: newBal,
                    balanceSnapshotAt: snapshotDate,
                  ),
                );
          }
        }
      }
    }

    state = [];
    return approved;
  }

  /// Dismisses a pending transaction and records tombstone to prevent re-import
  Future<void> dismiss(String id) async {
    final item = state.where((p) => p.id == id).firstOrNull;
    if (item != null) {
      final storage = _ref.read(storageServiceProvider);
      await storage.addDeletedTransactionSignature(item.signature);
      if (item.sourceMessageId != null) {
        await storage.addProcessedMessageId(item.sourceMessageId!);
      }
    }
    state = state.where((p) => p.id != id).toList();
  }

  /// Dismisses all pending transactions and records tombstones
  Future<void> dismissAll() async {
    final storage = _ref.read(storageServiceProvider);
    for (final item in state) {
      await storage.addDeletedTransactionSignature(item.signature);
      if (item.sourceMessageId != null) {
        await storage.addProcessedMessageId(item.sourceMessageId!);
      }
    }
    state = [];
  }
}
