import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/recurring_model.dart';
import '../models/notification_model.dart';
import '../models/debt_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../models/pending_transaction_model.dart';

class StorageService {
  static const _kTransactions = 'pocket_transactions';
  static const _kCategories = 'pocket_categories';
  static const _kWallets = 'pocket_wallets';
  static const _kSettings = 'pocket_settings';
  static const _kRecurringRules = 'pocket_recurring_rules';
  static const _kNotifications = 'pocket_notifications';
  static const _kDebts = 'pocket_debts';
  static const _kBudgets = 'pocket_category_budgets';
  static const _kGoals = 'pocket_goals';
  static const _kPendingTransactions = 'pocket_pending_transactions';
  static const _kEncryptionKeyName = 'pocket_storage_aes_key_v1';
  static const _kIsOnboardedFastFlag = 'pocket_is_onboarded_flag';

  final SharedPreferences _prefs;
  final enc.Encrypter? _encrypter;
  final List<int>? _hmacKey;
  final enc.Encrypter? _legacyEncrypter;

  // In-Memory Fast Caching Layer (O(1) memory lookup)
  List<TransactionModel>? _cachedTransactions;
  List<CategoryModel>? _cachedCategories;
  List<WalletModel>? _cachedWallets;
  UserSettingsModel? _cachedSettings;
  List<RecurringRuleModel>? _cachedRecurringRules;
  List<AppNotificationModel>? _cachedNotifications;
  List<DebtModel>? _cachedDebts;
  List<CategoryBudgetModel>? _cachedBudgets;
  List<GoalModel>? _cachedGoals;
  List<PendingTransactionModel>? _cachedPendingTransactions;

  StorageService(
    this._prefs, [
    FlutterSecureStorage? secureStorage,
    this._encrypter,
    this._hmacKey,
    this._legacyEncrypter,
  ]);

  static Future<StorageService> init({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    final effectiveSecureStorage = secureStorage ??
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

    enc.Encrypter? encrypter;
    enc.Encrypter? legacyEncrypter;
    List<int>? hmacKey;
    try {
      String? keyBase64 = await effectiveSecureStorage.read(key: _kEncryptionKeyName);
      if (keyBase64 == null || keyBase64.isEmpty) {
        // Migrate the legacy plaintext key once, then remove the weak copy.
        keyBase64 = effectivePrefs.getString('pocket_storage_aes_key_v1_backup');
      }
      if (keyBase64 == null || keyBase64.isEmpty) {
        final newKey = enc.Key.fromSecureRandom(32);
        keyBase64 = newKey.base64;
        await effectiveSecureStorage.write(key: _kEncryptionKeyName, value: keyBase64);
      } else {
        await effectiveSecureStorage.write(key: _kEncryptionKeyName, value: keyBase64);
      }
      await effectivePrefs.remove('pocket_storage_aes_key_v1_backup');
      final masterKeyBytes = base64.decode(keyBase64);

      // Key derivation for Authenticated Encryption (Encrypt-then-MAC with HMAC-SHA256):
      // 1. Encryption Key (32 bytes AES-256)
      final encKeyBytes = Hmac(sha256, masterKeyBytes).convert(utf8.encode('pocket_aes_enc_v2')).bytes;
      // 2. Authentication MAC Key (32 bytes HMAC-SHA256)
      hmacKey = Hmac(sha256, masterKeyBytes).convert(utf8.encode('pocket_hmac_auth_v2')).bytes;

      encrypter = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(encKeyBytes)), mode: enc.AESMode.cbc));
      legacyEncrypter = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(masterKeyBytes)), mode: enc.AESMode.cbc));
    } catch (e) {
      throw StateError('Secure storage initialization failed; refusing to store financial data in plaintext: $e');
    }

    final service = StorageService(effectivePrefs, effectiveSecureStorage, encrypter, hmacKey, legacyEncrypter);
    await service._migratePlaintextToEncrypted();
    await service._seedInitialDataIfNeeded();
    return service;
  }

  Future<void> reload() async {
    await _prefs.reload();
    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedTransactions = null;
    _cachedCategories = null;
    _cachedWallets = null;
    _cachedSettings = null;
    _cachedRecurringRules = null;
    _cachedNotifications = null;
    _cachedDebts = null;
    _cachedBudgets = null;
    _cachedGoals = null;
    _cachedPendingTransactions = null;
  }

  List<PendingTransactionModel> getPendingTransactions() {
    if (_cachedPendingTransactions != null) return _cachedPendingTransactions!;
    final raw = _decryptString(_prefs.getString(_kPendingTransactions));
    if (raw == null) return _cachedPendingTransactions = [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return _cachedPendingTransactions = decoded
          .map((e) => PendingTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _cachedPendingTransactions = [];
    }
  }

  Future<void> savePendingTransactions(List<PendingTransactionModel> items) async {
    _cachedPendingTransactions = List.unmodifiable(items);
    await _prefs.setString(
      _kPendingTransactions,
      _encryptString(jsonEncode(items.map((e) => e.toJson()).toList())),
    );
  }

  // --- Encryption Helpers ---

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  String _encryptString(String plaintext) {
    final encrypter = _encrypter;
    final hmacKey = _hmacKey;
    if (encrypter == null || hmacKey == null) return plaintext;
    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final authenticatedPayload = 'enc:v2:${iv.base64}:${encrypted.base64}';
      final mac = Hmac(sha256, hmacKey).convert(utf8.encode(authenticatedPayload)).bytes;
      return '$authenticatedPayload:${base64.encode(mac)}';
    } catch (e) {
      throw StateError('Financial data encryption failed: $e');
    }
  }

  String? _decryptString(String? ciphertext) {
    if (ciphertext == null) return null;

    // v2: Authenticated Encrypt-then-MAC (HMAC-SHA256)
    if (ciphertext.startsWith('enc:v2:')) {
      final encrypter = _encrypter;
      final hmacKey = _hmacKey;
      if (encrypter == null || hmacKey == null) return null;
      try {
        final parts = ciphertext.split(':');
        if (parts.length != 5) return null;
        final ivBase64 = parts[2];
        final encryptedBase64 = parts[3];
        final macBase64 = parts[4];

        final payloadToAuthenticate = 'enc:v2:$ivBase64:$encryptedBase64';
        final expectedMac = Hmac(sha256, hmacKey).convert(utf8.encode(payloadToAuthenticate)).bytes;
        final actualMac = base64.decode(macBase64);

        if (!_constantTimeEquals(expectedMac, actualMac)) {
          debugPrint('Security Warning: Ciphertext MAC authentication failed - data tampering detected.');
          return null;
        }

        final iv = enc.IV.fromBase64(ivBase64);
        final encrypted = enc.Encrypted.fromBase64(encryptedBase64);
        return encrypter.decrypt(encrypted, iv: iv);
      } catch (e) {
        debugPrint('Authenticated decryption error: $e');
        return null;
      }
    }

    // v1: Legacy AES-256-CBC without MAC (backward compatibility)
    if (ciphertext.startsWith('enc:v1:')) {
      final legacyEncrypter = _legacyEncrypter ?? _encrypter;
      if (legacyEncrypter == null) return null;
      try {
        final parts = ciphertext.split(':');
        if (parts.length != 4) return null;
        final iv = enc.IV.fromBase64(parts[2]);
        final encrypted = enc.Encrypted.fromBase64(parts[3]);
        return legacyEncrypter.decrypt(encrypted, iv: iv);
      } catch (e) {
        debugPrint('Legacy decryption error: $e');
        return null;
      }
    }

    // Reject any unrecognized or malformed 'enc:*' prefix without falling back to plaintext
    if (ciphertext.startsWith('enc:')) {
      debugPrint('Security Alert: Unrecognized or corrupted encrypted payload prefix: rejecting fallback.');
      return null;
    }

    // Legacy plaintext fallback
    return ciphertext;
  }

  @visibleForTesting
  String encryptForTest(String plaintext) => _encryptString(plaintext);

  @visibleForTesting
  String? decryptForTest(String? ciphertext) => _decryptString(ciphertext);

  Future<void> _migratePlaintextToEncrypted() async {
    const keys = [
      _kTransactions,
      _kCategories,
      _kWallets,
      _kSettings,
      _kRecurringRules,
      _kNotifications,
      _kDebts,
      _kBudgets,
      _kGoals,
      _kPendingTransactions,
    ];

    for (final key in keys) {
      final raw = _prefs.getString(key);
      if (raw != null && !raw.startsWith('enc:v2:')) {
        final decrypted = _decryptString(raw);
        if (decrypted != null) {
          final encrypted = _encryptString(decrypted);
          await _prefs.setString(key, encrypted);
        }
      }
    }
  }

  // --- Transactions ---

  List<TransactionModel> getTransactions() {
    if (_cachedTransactions != null) return _cachedTransactions!;
    final raw = _decryptString(_prefs.getString(_kTransactions));
    if (raw == null) {
      _cachedTransactions = [];
      return _cachedTransactions!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final list = decoded.map((e) => TransactionModel.fromJson(e)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      _cachedTransactions = list;
      return _cachedTransactions!;
    } catch (_) {
      _cachedTransactions = [];
      return _cachedTransactions!;
    }
  }

  Future<void> saveTransactions(List<TransactionModel> list) async {
    final sorted = List<TransactionModel>.from(list)..sort((a, b) => b.date.compareTo(a.date));
    _cachedTransactions = List.unmodifiable(sorted);
    final raw = jsonEncode(sorted.map((e) => e.toJson()).toList());
    await _prefs.setString(_kTransactions, _encryptString(raw));
  }

  // --- Categories ---

  List<CategoryModel> getCategories() {
    if (_cachedCategories != null) return _cachedCategories!;
    final raw = _decryptString(_prefs.getString(_kCategories));
    if (raw == null) {
      _cachedCategories = defaultCategories;
      return _cachedCategories!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedCategories = decoded.map((e) => CategoryModel.fromJson(e)).toList();
      return _cachedCategories!;
    } catch (_) {
      _cachedCategories = defaultCategories;
      return _cachedCategories!;
    }
  }

  Future<void> saveCategories(List<CategoryModel> list) async {
    _cachedCategories = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kCategories, _encryptString(raw));
  }

  // --- Wallets ---

  List<WalletModel> getWallets() {
    if (_cachedWallets != null) return _cachedWallets!;
    final raw = _decryptString(_prefs.getString(_kWallets));
    if (raw == null) {
      _cachedWallets = defaultWallets;
      return _cachedWallets!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedWallets = decoded.map((e) => WalletModel.fromJson(e)).toList();
      return _cachedWallets!;
    } catch (_) {
      _cachedWallets = defaultWallets;
      return _cachedWallets!;
    }
  }

  Future<void> saveWallets(List<WalletModel> list) async {
    _cachedWallets = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kWallets, _encryptString(raw));
  }

  UserSettingsModel getSettings() {
    if (_cachedSettings != null) return _cachedSettings!;
    UserSettingsModel settings = const UserSettingsModel();
    final raw = _decryptString(_prefs.getString(_kSettings));
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        settings = UserSettingsModel.fromJson(decoded);
      } catch (_) {
        settings = const UserSettingsModel();
      }
    }
    // Fast flag sync for cold restarts
    final fastOnboarded = _prefs.getBool(_kIsOnboardedFastFlag);
    if (fastOnboarded != null && fastOnboarded && !settings.isOnboarded) {
      settings = settings.copyWith(isOnboarded: true);
    }
    _cachedSettings = settings;
    return _cachedSettings!;
  }

  Future<void> saveSettings(UserSettingsModel settings) async {
    _cachedSettings = settings;
    await _prefs.setBool(_kIsOnboardedFastFlag, settings.isOnboarded);
    final raw = jsonEncode(settings.toJson());
    await _prefs.setString(_kSettings, _encryptString(raw));
  }

  bool isTransactionDeleted(String signature) {
    if (signature.trim().isEmpty) return false;
    return getSettings().deletedTransactionSignatures.contains(signature);
  }

  Future<void> addDeletedTransactionSignature(String signature) async {
    if (signature.trim().isEmpty) return;
    final current = getSettings();
    if (current.deletedTransactionSignatures.contains(signature)) return;
    final updated = List<String>.from(current.deletedTransactionSignatures)..add(signature);
    await saveSettings(current.copyWith(deletedTransactionSignatures: updated));
  }

  Future<void> removeDeletedTransactionSignature(String signature) async {
    if (signature.trim().isEmpty) return;
    final current = getSettings();
    if (!current.deletedTransactionSignatures.contains(signature)) return;
    final updated = current.deletedTransactionSignatures.where((s) => s != signature).toList();
    await saveSettings(current.copyWith(deletedTransactionSignatures: updated));
  }

  bool isMessageProcessed(String messageId) {
    if (messageId.trim().isEmpty) return false;
    return getSettings().processedMessageIds.contains(messageId);
  }

  Future<void> addProcessedMessageId(String messageId) async {
    if (messageId.trim().isEmpty) return;
    final current = getSettings();
    if (current.processedMessageIds.contains(messageId)) return;
    final updated = List<String>.from(current.processedMessageIds)..add(messageId);
    await saveSettings(current.copyWith(processedMessageIds: updated));
  }

  Future<void> addProcessedMessageIds(Iterable<String> messageIds) async {
    final valid = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (valid.isEmpty) return;
    final current = getSettings();
    final set = Set<String>.from(current.processedMessageIds)..addAll(valid);
    if (set.length != current.processedMessageIds.length) {
      await saveSettings(current.copyWith(processedMessageIds: set.toList()));
    }
  }

  Future<void> setLastSmsScanTimestamp(int timestamp) async {
    final current = getSettings();
    await saveSettings(current.copyWith(lastSmsScanTimestamp: timestamp));
  }

  bool hasAskedToAddMissedAccount(String accountKey) {
    if (accountKey.trim().isEmpty) return false;
    final asked = _prefs.getStringList('asked_missed_accounts') ?? [];
    return asked.contains(accountKey);
  }

  Future<void> markMissedAccountAsked(String accountKey) async {
    if (accountKey.trim().isEmpty) return;
    final asked = (_prefs.getStringList('asked_missed_accounts') ?? []).toSet();
    asked.add(accountKey);
    await _prefs.setStringList('asked_missed_accounts', asked.toList());
  }

  // --- Recurring Rules ---

  List<RecurringRuleModel> getRecurringRules() {
    if (_cachedRecurringRules != null) return _cachedRecurringRules!;
    final raw = _decryptString(_prefs.getString(_kRecurringRules));
    if (raw == null) {
      _cachedRecurringRules = [];
      return _cachedRecurringRules!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedRecurringRules = decoded.map((e) => RecurringRuleModel.fromJson(e)).toList();
      return _cachedRecurringRules!;
    } catch (_) {
      _cachedRecurringRules = [];
      return _cachedRecurringRules!;
    }
  }

  Future<void> saveRecurringRules(List<RecurringRuleModel> list) async {
    _cachedRecurringRules = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kRecurringRules, _encryptString(raw));
  }

  // --- In-App Notifications ---

  List<AppNotificationModel> getNotifications() {
    if (_cachedNotifications != null) return _cachedNotifications!;
    final raw = _decryptString(_prefs.getString(_kNotifications));
    if (raw == null) {
      _cachedNotifications = [];
      return _cachedNotifications!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedNotifications = decoded.map((e) => AppNotificationModel.fromJson(e)).toList();
      return _cachedNotifications!;
    } catch (_) {
      _cachedNotifications = [];
      return _cachedNotifications!;
    }
  }

  Future<void> saveNotifications(List<AppNotificationModel> list) async {
    _cachedNotifications = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kNotifications, _encryptString(raw));
  }

  Future<void> addNotification(AppNotificationModel notification) async {
    final current = getNotifications();
    await saveNotifications([notification, ...current]);
  }

  /// Suggests a category ID based on past transaction history and keyword heuristics
  String? suggestCategoryForTitle(
    String title,
    List<TransactionModel> pastTxs,
    List<CategoryModel> categories,
  ) {
    if (title.trim().isEmpty) return null;
    final lowerTitle = title.toLowerCase();

    // 1. Check exact/substring match against past transactions
    for (final tx in pastTxs) {
      if (tx.title.toLowerCase() == lowerTitle ||
          lowerTitle.contains(tx.title.toLowerCase()) ||
          tx.title.toLowerCase().contains(lowerTitle)) {
        return tx.categoryId;
      }
    }

    // 2. Keyword heuristics
    final keywords = {
      'food': ['zomato', 'swiggy', 'mcdonald', 'kfc', 'starbucks', 'coffee', 'dinner', 'lunch', 'breakfast', 'restaurant', 'cafe', 'burger', 'pizza', 'groceries', 'supermarket', 'blinkit', 'zepto', 'instamart'],
      'shopping': ['amazon', 'flipkart', 'myntra', 'zara', 'h&m', 'mall', 'clothing', 'shoes', 'electronics'],
      'transport': ['uber', 'ola', 'rapido', 'metro', 'bus', 'train', 'flight', 'petrol', 'fuel', 'diesel', 'cab', 'taxi', 'toll'],
      'bills': ['electricity', 'water', 'gas', 'wifi', 'broadband', 'recharge', 'airtel', 'jio', 'vi', 'bill', 'emi', 'loan'],
      'entertainment': ['netflix', 'prime', 'spotify', 'hotstar', 'cinema', 'pvr', 'movie', 'game', 'playstation', 'steam'],
      'health': ['pharmacy', 'hospital', 'doctor', 'clinic', 'medicine', 'apollo', 'practo', 'gym', 'fitness'],
      'salary': ['salary', 'payroll', 'stipend', 'dividend', 'interest'],
      'rent': ['rent', 'landlord', 'flat rent', 'maintenance'],
    };

    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        if (lowerTitle.contains(kw)) {
          final matchedCategory = categories.firstWhere(
            (c) => c.id == entry.key || c.name.toLowerCase() == entry.key,
            orElse: () => categories.first,
          );
          return matchedCategory.id;
        }
      }
    }

    return null;
  }

  // --- Debts / Lent / Borrowed ---

  List<DebtModel> getDebts() {
    if (_cachedDebts != null) return _cachedDebts!;
    final raw = _decryptString(_prefs.getString(_kDebts));
    if (raw == null) {
      _cachedDebts = [];
      return _cachedDebts!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedDebts = decoded.map((e) => DebtModel.fromJson(e)).toList();
      return _cachedDebts!;
    } catch (_) {
      _cachedDebts = [];
      return _cachedDebts!;
    }
  }

  Future<void> saveDebts(List<DebtModel> list) async {
    _cachedDebts = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kDebts, _encryptString(raw));
  }

  // --- Category Budgets ---

  List<CategoryBudgetModel> getCategoryBudgets() {
    if (_cachedBudgets != null) return _cachedBudgets!;
    final raw = _decryptString(_prefs.getString(_kBudgets));
    if (raw == null) {
      _cachedBudgets = [];
      return _cachedBudgets!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedBudgets = decoded.map((e) => CategoryBudgetModel.fromJson(e)).toList();
      return _cachedBudgets!;
    } catch (_) {
      _cachedBudgets = [];
      return _cachedBudgets!;
    }
  }

  Future<void> saveCategoryBudgets(List<CategoryBudgetModel> list) async {
    _cachedBudgets = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kBudgets, _encryptString(raw));
  }

  // --- Savings Goals ---

  List<GoalModel> getGoals() {
    if (_cachedGoals != null) return _cachedGoals!;
    final raw = _decryptString(_prefs.getString(_kGoals));
    if (raw == null) {
      _cachedGoals = [];
      return _cachedGoals!;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedGoals = decoded.map((e) => GoalModel.fromJson(e)).toList();
      return _cachedGoals!;
    } catch (_) {
      _cachedGoals = [];
      return _cachedGoals!;
    }
  }

  Future<void> saveGoals(List<GoalModel> list) async {
    _cachedGoals = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kGoals, _encryptString(raw));
  }

  // --- Startup Automated Recurring Engine ---

  Future<int> processDueRecurringRules() async {
    final rules = getRecurringRules();
    if (rules.isEmpty) return 0;

    final now = DateTime.now();
    final List<TransactionModel> txsToAdd = [];
    final List<AppNotificationModel> notifsToAdd = [];
    final List<RecurringRuleModel> updatedRules = [];
    int processedCount = 0;

    for (final rule in rules) {
      if (!rule.isActive || rule.isPaused) {
        updatedRules.add(rule);
        continue;
      }

      if (rule.nextDueDate.isBefore(now) || rule.nextDueDate.isAtSameMomentAs(now)) {
        final newTx = TransactionModel(
          id: const Uuid().v4(),
          title: rule.title,
          amount: rule.amount,
          type: rule.type,
          categoryId: rule.categoryId,
          walletId: rule.walletId,
          date: rule.nextDueDate,
          note: 'Auto-generated recurring payment (${rule.frequency.name})',
          createdAt: now,
        );
        txsToAdd.add(newTx);

        final notif = AppNotificationModel(
          id: const Uuid().v4(),
          title: 'Recurring payment: ${rule.title}',
          message: 'Auto-recorded payment of ₹${rule.amount.toStringAsFixed(0)} on ${rule.frequency.name} schedule.',
          type: NotificationType.recurringDue,
          createdAt: now,
        );
        notifsToAdd.add(notif);

        final nextDue = rule.calculateNextDueDateAfter(now);
        updatedRules.add(rule.copyWith(
          nextDueDate: nextDue,
          lastCreatedDate: now,
        ));
        processedCount++;
      } else {
        updatedRules.add(rule);
      }
    }

    if (processedCount > 0) {
      final currentTxs = getTransactions();
      await saveTransactions([...txsToAdd, ...currentTxs]);
      final currentNotifs = getNotifications();
      await saveNotifications([...notifsToAdd, ...currentNotifs]);
      await saveRecurringRules(updatedRules);
    }

    return processedCount;
  }

  // --- Initial Seed & Database Reset ---

  Future<void> _seedInitialDataIfNeeded() async {
    if (_prefs.getString(_kCategories) == null) {
      await saveCategories(defaultCategories);
    }
    if (_prefs.getString(_kWallets) == null) {
      await saveWallets(defaultWallets);
    }
  }

  Future<void> restoreDatabase(Map<String, dynamic> data) async {
    if (data['transactions'] != null) {
      final list = (data['transactions'] as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
      await saveTransactions(list);
    }
    if (data['wallets'] != null) {
      final list =
          (data['wallets'] as List).map((e) => WalletModel.fromJson(e)).toList();
      await saveWallets(list);
    }
    if (data['categories'] != null) {
      final list = (data['categories'] as List)
          .map((e) => CategoryModel.fromJson(e))
          .toList();
      await saveCategories(list);
    }
    final recurringData = data['recurringRules'] ?? data['recurring_rules'];
    if (recurringData != null) {
      final list = (recurringData as List)
          .map((e) => RecurringRuleModel.fromJson(e))
          .toList();
      await saveRecurringRules(list);
    }
    if (data['debts'] != null) {
      final list =
          (data['debts'] as List).map((e) => DebtModel.fromJson(e)).toList();
      await saveDebts(list);
    }
    final budgetsData = data['categoryBudgets'] ?? data['budgets'];
    if (budgetsData != null) {
      final list = (budgetsData as List)
          .map((e) => CategoryBudgetModel.fromJson(e))
          .toList();
      await saveCategoryBudgets(list);
    }
    if (data['goals'] != null) {
      final list =
          (data['goals'] as List).map((e) => GoalModel.fromJson(e)).toList();
      await saveGoals(list);
    }
    _invalidateCache();
  }

  Future<void> clearAllData() async {
    _invalidateCache();
    await _prefs.remove(_kTransactions);
    await _prefs.remove(_kRecurringRules);
    await _prefs.remove(_kNotifications);
    await _prefs.remove(_kDebts);
    await _prefs.remove(_kBudgets);
    await _prefs.remove(_kGoals);
    await saveCategories(defaultCategories);
    await saveWallets(defaultWallets);
    await saveSettings(const UserSettingsModel());
  }
}
