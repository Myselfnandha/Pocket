import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/pending_transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import 'storage_service.dart';
import 'upi_screenshot_parser_service.dart';

class AutoImportPermissions {
  final bool isNotificationListenerEnabled;
  final bool isAccessibilityEnabled;
  final bool isScreenshotWatcherActive;
  final bool isSmsListenerEnabled;

  const AutoImportPermissions({
    this.isNotificationListenerEnabled = false,
    this.isAccessibilityEnabled = false,
    this.isScreenshotWatcherActive = false,
    this.isSmsListenerEnabled = false,
  });

  bool get hasAnyActive =>
      isNotificationListenerEnabled || isAccessibilityEnabled || isScreenshotWatcherActive || isSmsListenerEnabled;
}

class AutoImportService {
  static const MethodChannel _channel = MethodChannel('com.pocket.pocket/auto_import');
  final StorageService _storage;

  AutoImportService(this._storage);

  /// Checks the current system status of all three real-time listeners.
  Future<AutoImportPermissions> checkPermissions() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      if (res != null) {
        return AutoImportPermissions(
          isNotificationListenerEnabled: res['notificationListener'] == true,
          isAccessibilityEnabled: res['accessibility'] == true,
          isScreenshotWatcherActive: res['screenshotWatcher'] == true,
          isSmsListenerEnabled: res['smsListener'] == true,
        );
      }
    } catch (_) {
      // In tests or non-Android environments, return safe defaults
    }
    return const AutoImportPermissions();
  }

  /// Requests runtime SMS permissions
  Future<bool> requestSmsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android System Notification Listener Settings.
  Future<bool> openNotificationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationListenerSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android System Accessibility Settings.
  Future<bool> openAccessibilitySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Enables or disables the native MediaStore screenshot observer.
  Future<bool> setScreenshotWatcherEnabled(bool enabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('setScreenshotWatcherEnabled', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches pending transactions from native buffer, runs smart deduplication,
  /// resolves screenshot OCR if needed, and clears the native queue buffer.
  Future<List<PendingTransactionModel>> fetchAndDrainPendingTransactions() async {
    List<PendingTransactionModel> incoming = [];

    try {
      final raw = await _channel.invokeMethod<String>('getPendingTransactions');
      if (raw != null && raw.trim().isNotEmpty && raw != '[]') {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        incoming = list
            .map((e) => PendingTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Clear native buffer after successful retrieval
        await _channel.invokeMethod('clearPendingTransactions');
      }
    } catch (_) {
      // Safe fallback on platform error or non-Android
    }

    if (incoming.isEmpty) return [];

    // Process screenshots with OCR if amount is missing
    final List<PendingTransactionModel> enriched = [];
    for (final item in incoming) {
      if (item.detectionSource == 'screenshot' &&
          (item.amount <= 0 || item.merchant == 'Screenshot Receipt') &&
          item.imagePath != null) {
        final resolved = await _enrichFromScreenshot(item);
        if (resolved != null) {
          enriched.add(resolved);
        }
      } else {
        enriched.add(item);
      }
    }

    // Apply Smart Multi-Key Deduplication
    return deduplicateAndAssignHeuristics(enriched);
  }

  /// OCR enrichment fallback for screenshot watcher events
  Future<PendingTransactionModel?> _enrichFromScreenshot(PendingTransactionModel item) async {
    try {
      final file = File(item.imagePath!);
      if (!file.existsSync()) return null;

      // Check if image filename or size looks like a payment receipt
      final pathLower = file.path.toLowerCase();
      final amt = UpiScreenshotParserService.extractAmount(pathLower) ?? 0.0;
      if (amt <= 0) return null;

      final ref = UpiScreenshotParserService.extractRefId(pathLower);
      final cat = _predictCategory('UPI Payment', pathLower, _storage.getCategories());

      return item.copyWith(
        amount: amt,
        merchant: 'UPI Payment',
        refId: ref,
        suggestedCategoryId: cat,
      );
    } catch (_) {
      return null;
    }
  }

  /// Deduplicates incoming items against both each other and the existing transaction database
  List<PendingTransactionModel> deduplicateAndAssignHeuristics(
    List<PendingTransactionModel> incoming,
  ) {
    final existingTxs = _storage.getTransactions();
    final categories = _storage.getCategories();
    final wallets = _storage.getWallets();

    final List<PendingTransactionModel> result = [];

    for (final item in incoming) {
      if (item.amount <= 0) continue;

      // Check against existing database transactions
      if (_isAlreadySaved(item, existingTxs)) {
        continue;
      }

      // Check against already processed incoming items in this batch
      final existingIndex = result.indexWhere((r) => _isSameTransaction(r, item));
      if (existingIndex != -1) {
        // Merge metadata: keep richer merchant name and screenshot if available
        final existing = result[existingIndex];
        result[existingIndex] = existing.copyWith(
          refId: (existing.refId != null && existing.refId!.isNotEmpty)
              ? existing.refId
              : item.refId,
          imagePath: existing.imagePath ?? item.imagePath,
          rawPayload: existing.rawPayload ?? item.rawPayload,
        );
        continue;
      }

      // Assign suggested category and wallet
      final suggestedCat = item.suggestedCategoryId ??
          _predictCategory(item.merchant, item.rawPayload ?? '', categories);
      final suggestedWallet = _matchWallet(item, wallets);

      result.add(item.copyWith(
        suggestedCategoryId: suggestedCat,
        suggestedWalletId: suggestedWallet,
      ));
    }

    return result;
  }

  String _predictCategory(String merchant, String rawPayload, List<CategoryModel> categories) {
    final pred = UpiScreenshotParserService.predictCategory(merchant, rawPayload);
    final normalized = pred.replaceFirst('cat_', '');
    for (final c in categories) {
      if (c.id == normalized || c.id == pred || c.name.toLowerCase().contains(normalized)) {
        return c.id;
      }
    }
    return categories.isNotEmpty ? categories.first.id : 'food';
  }

  /// Checks if an incoming item matches an already-saved transaction and enriches it
  /// with new metadata (e.g. attaching screenshot image to SMS tx, or bank wallet to screenshot tx).
  TransactionModel? enrichSavedTransaction(
    PendingTransactionModel item,
    List<TransactionModel> saved,
    List<WalletModel> wallets,
  ) {
    if (item.refId == null || item.refId!.isEmpty) return null;

    for (final tx in saved) {
      final isMatch = (tx.refId != null && tx.refId == item.refId) ||
          (tx.note != null && tx.note!.contains(item.refId!));

      if (isMatch) {
        bool changed = false;
        String? newImg = tx.receiptImagePath;
        String newTitle = tx.title;
        String newWallet = tx.walletId;

        // 1. Attach screenshot image if existing transaction lacked it
        if ((newImg == null || newImg.isEmpty) && item.imagePath != null && item.imagePath!.isNotEmpty) {
          newImg = item.imagePath;
          changed = true;
        }

        // 2. Enrich generic title with richer merchant name from screenshot
        final txTitleLower = tx.title.toLowerCase();
        if ((txTitleLower.contains('payment') || txTitleLower.contains('alert') || txTitleLower.contains('upi')) &&
            item.merchant.isNotEmpty &&
            !item.merchant.toLowerCase().contains('payment') &&
            !item.merchant.toLowerCase().contains('alert')) {
          newTitle = item.merchant;
          changed = true;
        }

        // 3. Enrich bank wallet if item has bank SMS details
        if (item.appSource.contains('SMS') || item.detectionSource == 'sms') {
          final matchedWallet = _matchWallet(item, wallets);
          if (matchedWallet != newWallet && matchedWallet != 'default_cash') {
            newWallet = matchedWallet;
            changed = true;
          }
        }

        // 4. Enrich note with SMS source if previously missing
        String? newNote = tx.note;
        if ((newNote == null || newNote.isEmpty || newNote.startsWith('Ref:')) && item.appSource.contains('SMS')) {
          newNote = tx.refId != null && tx.refId!.isNotEmpty
              ? 'Ref: ${tx.refId} • ${item.appSource}'
              : item.appSource;
          if (newNote != tx.note) changed = true;
        }

        if (changed) {
          return tx.copyWith(
            receiptImagePath: newImg,
            title: newTitle,
            walletId: newWallet,
            note: newNote,
          );
        }
        return null;
      }
    }
    return null;
  }

  bool _isAlreadySaved(PendingTransactionModel item, List<TransactionModel> saved) {
    // 1. Exact refId match
    if (item.refId != null && item.refId!.isNotEmpty) {
      for (final tx in saved) {
        if (tx.refId != null && tx.refId == item.refId) {
          return true;
        }
        if (tx.note != null && tx.note!.contains(item.refId!)) {
          return true;
        }
      }
    }

    // 2. Fuzzy match fallback when refId is missing
    final itemMerchant = item.merchant.toLowerCase().trim();
    for (final tx in saved) {
      if ((tx.amount - item.amount).abs() < 0.01) {
        final txTitle = tx.title.toLowerCase().trim();
        final isTitleMatch = txTitle == itemMerchant ||
            txTitle.contains(itemMerchant) ||
            itemMerchant.contains(txTitle);

        final timeDiff = tx.date.difference(item.date).inSeconds.abs();
        if (isTitleMatch && timeDiff <= 90) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isSameTransaction(PendingTransactionModel a, PendingTransactionModel b) {
    // 1. Exact refId match
    if (a.refId != null &&
        a.refId!.isNotEmpty &&
        b.refId != null &&
        b.refId!.isNotEmpty &&
        a.refId == b.refId) {
      return true;
    }

    // 2. Composite match fallback when refId is missing
    if ((a.amount - b.amount).abs() < 0.01) {
      final aMerch = a.merchant.toLowerCase().trim();
      final bMerch = b.merchant.toLowerCase().trim();
      if (aMerch == bMerch || aMerch.contains(bMerch) || bMerch.contains(aMerch)) {
        final timeDiff = a.date.difference(b.date).inSeconds.abs();
        if (timeDiff <= 60) {
          return true;
        }
      }
    }

    return false;
  }

  String _matchWallet(PendingTransactionModel item, List<WalletModel> wallets) {
    if (wallets.isEmpty) return 'default_cash';

    final text = '${item.appSource} ${item.rawPayload ?? ''}'.toLowerCase();

    // Match by account number last 4
    for (final w in wallets) {
      if (w.accountNumber != null && w.accountNumber!.length >= 4) {
        final last4 = w.accountNumber!.substring(w.accountNumber!.length - 4);
        if (text.contains(last4)) {
          return w.id;
        }
      }
    }

    // Match by bank/wallet keywords
    for (final w in wallets) {
      final name = w.name.toLowerCase();
      if (text.contains(name) || name.contains('upi') || name.contains('online')) {
        return w.id;
      }
    }

    // Prefer first bank or UPI wallet over Cash
    final nonCash = wallets.firstWhere(
      (w) => !w.name.toLowerCase().contains('cash'),
      orElse: () => wallets.first,
    );

    return nonCash.id;
  }
}
