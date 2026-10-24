import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/pending_transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import 'storage_service.dart';
import 'upi_screenshot_parser_service.dart';
import 'bank_discovery_service.dart';

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

  /// Requests runtime SMS permissions.
  Future<bool> requestSmsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      final granted = res ?? false;
      if (granted) {
        final currentSettings = _storage.getSettings();
        await setAutoSaveSmsPreference(currentSettings.autoSaveSms);
      }
      return granted;
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

  /// Opens App Details Settings in Android System Settings.
  Future<bool> openAppSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppSettings');
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

  /// Sets native SharedPreferences auto-save preference for background SmsReceiver.
  Future<bool> setAutoSaveSmsPreference(bool enabled) async {
    try {
      final res = await _channel.invokeMethod<bool>('setAutoSaveSmsPreference', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Scans the device SMS inbox for bank transactions within [daysLookback] days (0 = all).
  Future<List<PendingTransactionModel>> scanSmsInbox({int daysLookback = 30}) async {
    try {
      final raw = await _channel.invokeMethod<String>('scanSmsInbox', {'days': daysLookback});
      if (raw != null && raw.trim().isNotEmpty && raw != '[]') {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final incoming = list
            .map((e) => PendingTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return deduplicateAndAssignHeuristics(incoming);
      }
    } catch (_) {
      // Safe fallback on platform error or non-Android
    }
    return [];
  }

  /// Fetches pending transactions from native buffer, persists them, then clears
  /// the native queue. Keeping persistence before acknowledgement avoids loss if
  /// the app is killed while processing the import.
  Future<List<PendingTransactionModel>> fetchAndDrainPendingTransactions() async {
    List<PendingTransactionModel> incoming = [];

    try {
      final raw = await _channel.invokeMethod<String>('getPendingTransactions');
      if (raw != null && raw.trim().isNotEmpty && raw != '[]') {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        incoming = list
            .map((e) => PendingTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();

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
    final result = deduplicateAndAssignHeuristics(enriched);
    final durable = deduplicateAndAssignHeuristics([
      ..._storage.getPendingTransactions(),
      ...result,
    ]);
    await _storage.savePendingTransactions(durable);
    if (incoming.isNotEmpty) {
      await _channel.invokeMethod('clearPendingTransactions');
    }
    return result;
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
          _predictCategory(
            item.merchant,
            item.rawPayload ?? '',
            categories,
            isIncome: item.isIncome,
            appSource: item.appSource,
            senderBank: item.senderBank,
            detectionSource: item.detectionSource,
          );
      final suggestedWallet = _matchWallet(item, wallets);

      result.add(item.copyWith(
        suggestedCategoryId: suggestedCat,
        suggestedWalletId: suggestedWallet,
      ));
    }

    return result;
  }

  String _predictCategory(
    String merchant,
    String rawPayload,
    List<CategoryModel> categories, {
    bool isIncome = false,
    String? appSource,
    String? senderBank,
    String? detectionSource,
  }) {
    final pred = UpiScreenshotParserService.predictCategory(
      merchant,
      rawPayload,
      isIncome: isIncome,
      source: appSource,
      senderBank: senderBank,
    );
    final normalized = pred.replaceFirst('cat_', '');

    // Map common aliases to default category IDs
    final aliasMap = {
      'bills': 'utilities',
      'bill': 'utilities',
      'investment': 'investments',
      'others': isIncome ? 'other_inc' : 'other_exp',
      'other': isIncome ? 'other_inc' : 'other_exp',
    };
    final targetId = aliasMap[normalized] ?? normalized;

    // 1. First try matching categories matching transaction type by ID
    for (final c in categories) {
      if ((isIncome ? c.type == TransactionType.income : c.type == TransactionType.expense) &&
          (c.id == targetId || c.id == normalized || c.id == pred)) {
        return c.id;
      }
    }

    // 2. Next try matching category name matching transaction type
    for (final c in categories) {
      if ((isIncome ? c.type == TransactionType.income : c.type == TransactionType.expense) &&
          (c.name.toLowerCase().contains(targetId) || c.name.toLowerCase().contains(normalized))) {
        return c.id;
      }
    }

    // 3. Match against merchant name directly in existing categories
    final cleanMerchant = _cleanCategoryName(merchant);
    for (final c in categories) {
      if (c.name.toLowerCase() == cleanMerchant.toLowerCase() ||
          c.name.toLowerCase().contains(cleanMerchant.toLowerCase()) ||
          cleanMerchant.toLowerCase().contains(c.name.toLowerCase())) {
        if (cleanMerchant.length >= 3 && !_isGenericMerchant(cleanMerchant)) {
          return c.id;
        }
      }
    }

    // 4. Fallback search across all categories by ID or Name
    for (final c in categories) {
      if (c.id == targetId || c.id == normalized || c.id == pred ||
          c.name.toLowerCase().contains(targetId) || c.name.toLowerCase().contains(normalized)) {
        return c.id;
      }
    }

    // 5. Intelligent Category Auto-Creation: If not matched in existing categories, create once
    if (cleanMerchant.length >= 2 && !_isGenericMerchant(cleanMerchant)) {
      final newId = 'cat_${cleanMerchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final currentCats = _storage.getCategories();
      final existing = currentCats.where((c) => c.id == newId || c.name.toLowerCase() == cleanMerchant.toLowerCase()).firstOrNull;
      if (existing != null) {
        return existing.id;
      }

      final newCat = CategoryModel(
        id: newId,
        name: cleanMerchant,
        icon: _pickCategoryIcon(cleanMerchant, isIncome),
        colorValue: _generateColorForCategory(cleanMerchant),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        isDefault: false,
      );

      final updated = [...currentCats, newCat];
      _storage.saveCategories(updated);
      return newCat.id;
    }

    // 6. Direction-aware defaults
    if (isIncome) {
      final incomeCats = categories.where((c) => c.type == TransactionType.income).toList();
      return incomeCats.isNotEmpty ? incomeCats.first.id : 'salary';
    }

    final expenseCats = categories.where((c) => c.type == TransactionType.expense).toList();
    return expenseCats.isNotEmpty ? expenseCats.first.id : 'food';
  }

  static bool _isGenericMerchant(String name) {
    final lower = name.toLowerCase().trim();
    return lower.isEmpty ||
        lower == 'payment' ||
        lower == 'upi payment' ||
        lower == 'payment received' ||
        lower == 'debit' ||
        lower == 'credit' ||
        lower == 'transfer' ||
        lower == 'deposit' ||
        lower == 'bank transfer';
  }

  static String _cleanCategoryName(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'(?i)\b(ltd|pvt|limited|india|store|pos|ecom|vpa|bank|a/c|acct)\b'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s&-]'), '')
        .trim();
    if (cleaned.isEmpty) return 'Other';
    return cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) {
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  static String _pickCategoryIcon(String name, bool isIncome) {
    if (isIncome) return '💰';
    final lower = name.toLowerCase();
    if (lower.contains('gym') || lower.contains('fitness') || lower.contains('cult')) return '🏋️';
    if (lower.contains('steam') || lower.contains('game') || lower.contains('play')) return '🎮';
    if (lower.contains('book') || lower.contains('edu') || lower.contains('class')) return '📚';
    if (lower.contains('pet') || lower.contains('vet')) return '🐾';
    if (lower.contains('spa') || lower.contains('salon') || lower.contains('barber')) return '💇';
    if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('diesel') || lower.contains('shell')) return '⛽';
    if (lower.contains('coffee') || lower.contains('tea') || lower.contains('cafe') || lower.contains('starbucks')) return '☕';
    if (lower.contains('food') || lower.contains('dine') || lower.contains('swiggy') || lower.contains('zomato') || lower.contains('mcdonald')) return '🍔';
    if (lower.contains('uber') || lower.contains('ola') || lower.contains('rapido') || lower.contains('metro')) return '🚗';
    if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('zara') || lower.contains('shop')) return '🛍️';
    if (lower.contains('hotel') || lower.contains('resort') || lower.contains('stay') || lower.contains('travel')) return '✈️';
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('doctor') || lower.contains('pharmacy')) return '🏥';
    return '🏷️';
  }

  static int _generateColorForCategory(String name) {
    const palette = [
      0xFF3F51B5, // Indigo
      0xFF009688, // Teal
      0xFF673AB7, // Deep Purple
      0xFFE91E63, // Pink
      0xFF00BCD4, // Cyan
      0xFFFF5722, // Deep Orange
      0xFF607D8B, // Blue Grey
      0xFF8BC34A, // Light Green
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
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
          final matchedWallet = findExplicitMatchingWallet(item, wallets);
          if (matchedWallet != null && matchedWallet != newWallet) {
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

  /// Public helper to check if a pending transaction has already been saved into the database or previously deleted by user
  bool isAlreadySaved(PendingTransactionModel item, List<TransactionModel> saved, [int? windowSeconds]) {
    // 0. Tombstone & Processed Check (Never re-import deleted or handled items)
    if (_storage.isTransactionDeleted(item.signature)) {
      return true;
    }
    if (item.sourceMessageId != null && _storage.isMessageProcessed(item.sourceMessageId!)) {
      return true;
    }

    // 1. Exact signature match against active transactions
    final itemSig = item.signature;
    for (final tx in saved) {
      if (tx.signature == itemSig) {
        return true;
      }
    }

    // 2. Exact refId match
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

    // 3. MANDATORY Sliding Time-Window Fuzzy Matching for SMS & pending transactions
    // When refId is absent or across differing sources, deduplicate via floating point amount tolerance
    // and configured sliding time window.
    final window = windowSeconds ?? _storage.getSettings().duplicateDetectionWindowSeconds;
    final itemMerchant = item.merchant.toLowerCase().trim();
    for (final tx in saved) {
      if ((tx.amount - item.amount).abs() < 0.01) {
        final txTitle = tx.title.toLowerCase().trim();
        final isTitleMatch = txTitle == itemMerchant ||
            txTitle.contains(itemMerchant) ||
            itemMerchant.contains(txTitle) ||
            _isGenericMerchant(txTitle) ||
            _isGenericMerchant(itemMerchant);

        final timeDiff = tx.date.difference(item.date).inSeconds.abs();
        if (isTitleMatch && timeDiff <= window) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isAlreadySaved(PendingTransactionModel item, List<TransactionModel> saved) =>
      isAlreadySaved(item, saved);

  bool _isSameTransaction(PendingTransactionModel a, PendingTransactionModel b) {
    // 1. Exact refId match
    if (a.refId != null &&
        a.refId!.isNotEmpty &&
        b.refId != null &&
        b.refId!.isNotEmpty &&
        a.refId == b.refId) {
      return true;
    }

    // 2. Mandatory Sliding Time-Window Fuzzy Matching
    final window = _storage.getSettings().duplicateDetectionWindowSeconds;
    if ((a.amount - b.amount).abs() < 0.01) {
      final aMerch = a.merchant.toLowerCase().trim();
      final bMerch = b.merchant.toLowerCase().trim();
      final isTitleMatch = aMerch == bMerch ||
          aMerch.contains(bMerch) ||
          bMerch.contains(aMerch) ||
          _isGenericMerchant(aMerch) ||
          _isGenericMerchant(bMerch);

      if (isTitleMatch) {
        final timeDiff = a.date.difference(b.date).inSeconds.abs();
        if (timeDiff <= window) {
          return true;
        }
      }
    }

    return false;
  }

  String _matchWallet(PendingTransactionModel item, List<WalletModel> wallets) {
    if (wallets.isEmpty) return 'cash';

    // 1. First attempt explicit matching (by account digits, sender bank, or bank keywords)
    final explicitMatch = findExplicitMatchingWallet(item, wallets);
    if (explicitMatch != null) {
      return explicitMatch;
    }

    // 2. If no wallet matches, assign the default primary wallet
    final defaultWallet = wallets.where((w) => w.isDefault).firstOrNull;
    if (defaultWallet != null) {
      return defaultWallet.id;
    }

    final text = '${item.appSource} ${item.rawPayload ?? ''}'.toLowerCase();

    // 3. If it's a UPI transaction, match a dedicated UPI wallet if present
    if (text.contains('upi') || text.contains('gpay') || text.contains('phonepe') || text.contains('paytm')) {
      final upiWallet = wallets.where((w) =>
          w.walletType == WalletType.upi ||
          w.name.toLowerCase().contains('upi') ||
          w.name.toLowerCase().contains('paytm')
      ).firstOrNull;
      if (upiWallet != null) {
        return upiWallet.id;
      }
    }

    // 4. Fallback to first non-cash wallet, or first available wallet
    final nonCash = wallets.firstWhere(
      (w) => !w.name.toLowerCase().contains('cash'),
      orElse: () => wallets.first,
    );

    return nonCash.id;
  }

  /// Explicitly matches an incoming transaction against user accounts by last-4 account digits,
  /// sender bank name, or bank acronym keywords.
  /// Returns null if no explicit matching account can be safely identified.
  String? findExplicitMatchingWallet(PendingTransactionModel item, List<WalletModel> wallets) {
    if (wallets.isEmpty) return null;

    // 1. Direct match by counterparty account last 4 digits
    if (item.counterpartyLast4 != null && item.counterpartyLast4!.isNotEmpty) {
      for (final w in wallets) {
        if (w.accountNumber != null && w.accountNumber!.contains(item.counterpartyLast4!)) {
          return w.id;
        }
      }
    }

    final text = '${item.appSource} ${item.rawPayload ?? ''} ${item.merchant}'.toLowerCase();

    // 2. Match by account number last 4 digits in raw message text
    for (final w in wallets) {
      if (w.accountNumber != null && w.accountNumber!.trim().isNotEmpty) {
        final cleanAcct = w.accountNumber!.replaceAll(RegExp(r'\D'), '');
        if (cleanAcct.length >= 4) {
          final last4 = cleanAcct.substring(cleanAcct.length - 4);
          if (text.contains(last4)) {
            return w.id;
          }
        }
      }
    }

    // 3. Match by explicit senderBank if present
    if (item.senderBank != null && item.senderBank!.trim().isNotEmpty) {
      final senderBank = item.senderBank!.toLowerCase().trim();
      for (final w in wallets) {
        final name = w.name.toLowerCase().trim();
        if (name.isNotEmpty && name != 'cash' && name != 'wallet') {
          if (name.contains(senderBank) || senderBank.contains(name)) {
            return w.id;
          }
        }
      }
    }

    // 4. Match by bank name keywords (e.g. HDFC, SBI, ICICI, Axis, Kotak, Indian Bank, IndusInd)
    for (final w in wallets) {
      final name = w.name.toLowerCase().trim();
      if (name.isNotEmpty && name != 'cash' && name != 'wallet' && name != 'main account') {
        if (text.contains(name)) {
          return w.id;
        }
      }
    }

    // 5. Match by bank SMS acronyms / gateway headers against wallet names
    for (final w in wallets) {
      final name = w.name.toLowerCase();
      if ((text.contains('indusb') || text.contains('indusind')) && name.contains('indusind')) return w.id;
      if ((text.contains('indbnk') || text.contains('indian bank')) && name.contains('indian')) return w.id;
      if (text.contains('hdfc') && name.contains('hdfc')) return w.id;
      if ((text.contains('sbi') || text.contains('state bank')) && (name.contains('sbi') || name.contains('state bank'))) return w.id;
      if (text.contains('icici') && name.contains('icici')) return w.id;
      if (text.contains('axis') && name.contains('axis')) return w.id;
      if (text.contains('kotak') && name.contains('kotak')) return w.id;
      if ((text.contains('pnb') || text.contains('punjab national')) && (name.contains('pnb') || name.contains('punjab'))) return w.id;
      if ((text.contains('bob') || text.contains('bank of baroda')) && (name.contains('bob') || name.contains('baroda'))) return w.id;
      if (text.contains('canara') && name.contains('canara')) return w.id;
      if ((text.contains('union') || text.contains('ubin') || text.contains('uboi')) && name.contains('union')) return w.id;
      if (text.contains('idfc') && name.contains('idfc')) return w.id;
      if (text.contains('federal') && name.contains('federal')) return w.id;
      if (text.contains('rbl') && name.contains('rbl')) return w.id;
      if (text.contains('yes bank') && name.contains('yes')) return w.id;
    }

    return null;
  }

  /// Public category prediction helper with source-based and UPI VPA heuristics
  String predictCategory(
    String merchant,
    String rawPayload,
    List<CategoryModel> categories, {
    bool isIncome = false,
    String? appSource,
    String? senderBank,
    String? detectionSource,
  }) =>
      _predictCategory(
        merchant,
        rawPayload,
        categories,
        isIncome: isIncome,
        appSource: appSource,
        senderBank: senderBank,
        detectionSource: detectionSource,
      );

  /// Public wallet matching helper
  String matchWallet(PendingTransactionModel item, List<WalletModel> wallets) =>
      _matchWallet(item, wallets);

  /// Scans device SMS inbox and saves only items with an explicit account match.
  /// Unmatched items remain in the durable review queue.
  /// Returns the number of successfully logged transactions.
  Future<int> autoLogPastSmsTransactions({int daysLookback = 0}) async {
    final perms = await checkPermissions();
    if (!perms.isSmsListenerEnabled) {
      final granted = await requestSmsPermission();
      if (!granted) return 0;
    }

    final rawPast = await scanSmsInbox(daysLookback: daysLookback);
    if (rawPast.isEmpty) return 0;

    final existingTxs = _storage.getTransactions();
    final categories = _storage.getCategories();
    final wallets = _storage.getWallets();

    final List<TransactionModel> txsToSave = [];
    final List<PendingTransactionModel> unmatchedItems = [];
    final List<String> processedMsgIds = [];

    final Map<String, ({double balance, DateTime date})> latestWalletBalances = {};

    for (final item in rawPast) {
      if (item.amount <= 0) continue;
      if (isAlreadySaved(item, existingTxs)) continue;

      // Deduplicate against items already in this batch
      final alreadyInBatch = txsToSave.any((t) =>
          (item.refId != null && item.refId!.isNotEmpty && t.refId == item.refId) ||
          ((t.amount - item.amount).abs() < 0.01 &&
              t.date.difference(item.date).inSeconds.abs() <= 90 &&
              (t.title.toLowerCase() == item.merchant.toLowerCase())));
      if (alreadyInBatch) continue;

      final matchedWalletId = findExplicitMatchingWallet(item, wallets);

      final effectiveCategoryId = item.suggestedCategoryId ??
          _predictCategory(
            item.merchant,
            item.rawPayload ?? '',
            categories,
            isIncome: item.isIncome,
            appSource: item.appSource,
            senderBank: item.senderBank,
            detectionSource: item.detectionSource,
          );

      final effectiveNote = item.refId != null && item.refId!.isNotEmpty
          ? 'Ref: ${item.refId}'
          : (item.appSource.isNotEmpty ? 'Auto-Logged via ${item.appSource}' : null);

      if (matchedWalletId == null) {
        unmatchedItems.add(item.copyWith(suggestedCategoryId: effectiveCategoryId));
        continue;
      }

      txsToSave.add(
        TransactionModel(
          id: item.id.isNotEmpty ? item.id : const Uuid().v4(),
          title: item.merchant.trim().isNotEmpty ? item.merchant.trim() : (item.isIncome ? 'Deposit' : 'Payment'),
          amount: item.amount,
          type: item.isIncome ? TransactionType.income : TransactionType.expense,
          categoryId: effectiveCategoryId,
          walletId: matchedWalletId,
          date: item.date,
          note: effectiveNote,
          refId: item.refId,
          counterpartyLast4: item.counterpartyLast4,
          appSource: item.appSource,
          rawPayload: item.rawPayload,
          createdAt: item.date,
        ),
      );

      if (item.sourceMessageId != null) {
        processedMsgIds.add(item.sourceMessageId!);
      }

      // Track available balance if reported in the message
      final extractedBal = BankDiscoveryService.extractAvailableBalance(item.rawPayload);
      if (extractedBal != null) {
        final currentLatest = latestWalletBalances[matchedWalletId];
        if (currentLatest == null || item.date.isAfter(currentLatest.date)) {
          latestWalletBalances[matchedWalletId] = (balance: extractedBal, date: item.date);
        }
      }
    }

    if (txsToSave.isNotEmpty) {
      await _storage.saveTransactions([...existingTxs, ...txsToSave]);
      for (final msgId in processedMsgIds) {
        await _storage.addProcessedMessageId(msgId);
      }

      // Update wallet balances with fresh SMS balances if available
      if (latestWalletBalances.isNotEmpty && wallets.isNotEmpty) {
        final updatedWallets = wallets.map((w) {
          final latestBal = latestWalletBalances[w.id];
          if (latestBal != null) {
            final isFresher = w.balanceSnapshotAt == null ||
                latestBal.date.isAfter(w.balanceSnapshotAt!) ||
                latestBal.date.isAtSameMomentAs(w.balanceSnapshotAt!);
            if (isFresher) {
              return w.copyWith(
                initialBalance: latestBal.balance,
                currentBalance: latestBal.balance,
                balanceSnapshotAt: latestBal.date,
              );
            }
          }
          return w;
        }).toList();
        await _storage.saveWallets(updatedWallets);
      }
    }

    if (unmatchedItems.isNotEmpty) {
      await _storage.savePendingTransactions(deduplicateAndAssignHeuristics([
        ..._storage.getPendingTransactions(),
        ...unmatchedItems,
      ]));
    }

    return txsToSave.length;
  }
}
