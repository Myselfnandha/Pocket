import 'dart:convert';
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
  static const _kEncryptionKeyName = 'pocket_storage_aes_key_v1';

  final SharedPreferences _prefs;
  final enc.Encrypter? _encrypter;

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

  StorageService(this._prefs, [FlutterSecureStorage? secureStorage, this._encrypter]);

  static Future<StorageService> init({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    final effectiveSecureStorage = secureStorage ?? const FlutterSecureStorage();

    enc.Encrypter? encrypter;
    try {
      String? keyBase64 = await effectiveSecureStorage.read(key: _kEncryptionKeyName);
      if (keyBase64 == null || keyBase64.isEmpty) {
        final newKey = enc.Key.fromSecureRandom(32);
        keyBase64 = newKey.base64;
        await effectiveSecureStorage.write(key: _kEncryptionKeyName, value: keyBase64);
      }
      final key = enc.Key.fromBase64(keyBase64);
      encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    } catch (e) {
      debugPrint('Storage encryption init notice (fallback mode): $e');
    }

    final service = StorageService(effectivePrefs, effectiveSecureStorage, encrypter);
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
  }

  // --- Encryption Helpers ---

  String _encryptString(String plaintext) {
    final encrypter = _encrypter;
    if (encrypter == null) return plaintext;
    try {
      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      return 'enc:v1:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('Encryption error: $e');
      return plaintext;
    }
  }

  String? _decryptString(String? ciphertext) {
    if (ciphertext == null) return null;
    if (!ciphertext.startsWith('enc:v1:')) return ciphertext; // Legacy plaintext fallback
    final encrypter = _encrypter;
    if (encrypter == null) return null;
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 4) return null;
      final iv = enc.IV.fromBase64(parts[2]);
      final encrypted = enc.Encrypted.fromBase64(parts[3]);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

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
    ];

    for (final key in keys) {
      final raw = _prefs.getString(key);
      if (raw != null && !raw.startsWith('enc:v1:')) {
        final encrypted = _encryptString(raw);
        await _prefs.setString(key, encrypted);
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
      _cachedTransactions = decoded.map((e) => TransactionModel.fromJson(e)).toList();
      return _cachedTransactions!;
    } catch (_) {
      _cachedTransactions = [];
      return _cachedTransactions!;
    }
  }

  Future<void> saveTransactions(List<TransactionModel> list) async {
    _cachedTransactions = List.unmodifiable(list);
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
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

  // --- Settings ---

  UserSettingsModel getSettings() {
    if (_cachedSettings != null) return _cachedSettings!;
    final raw = _decryptString(_prefs.getString(_kSettings));
    if (raw == null) {
      _cachedSettings = const UserSettingsModel();
      return _cachedSettings!;
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      _cachedSettings = UserSettingsModel.fromJson(decoded);
      return _cachedSettings!;
    } catch (_) {
      _cachedSettings = const UserSettingsModel();
      return _cachedSettings!;
    }
  }

  Future<void> saveSettings(UserSettingsModel settings) async {
    _cachedSettings = settings;
    final raw = jsonEncode(settings.toJson());
    await _prefs.setString(_kSettings, _encryptString(raw));
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
    if (data['recurring_rules'] != null) {
      final list = (data['recurring_rules'] as List)
          .map((e) => RecurringRuleModel.fromJson(e))
          .toList();
      await saveRecurringRules(list);
    }
    if (data['debts'] != null) {
      final list =
          (data['debts'] as List).map((e) => DebtModel.fromJson(e)).toList();
      await saveDebts(list);
    }
    if (data['budgets'] != null) {
      final list = (data['budgets'] as List)
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
