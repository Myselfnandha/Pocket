import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/recurring_model.dart';
import '../models/notification_model.dart';
import '../models/debt_model.dart';

class StorageService {
  static const _kTransactions = 'pocket_transactions';
  static const _kCategories = 'pocket_categories';
  static const _kWallets = 'pocket_wallets';
  static const _kSettings = 'pocket_settings';
  static const _kRecurringRules = 'pocket_recurring_rules';
  static const _kNotifications = 'pocket_notifications';
  static const _kDebts = 'pocket_debts';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedInitialDataIfNeeded();
    return service;
  }

  // --- Transactions ---

  List<TransactionModel> getTransactions() {
    final raw = _prefs.getString(_kTransactions);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => TransactionModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(List<TransactionModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kTransactions, raw);
  }

  // --- Categories ---

  List<CategoryModel> getCategories() {
    final raw = _prefs.getString(_kCategories);
    if (raw == null) return defaultCategories;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => CategoryModel.fromJson(e)).toList();
    } catch (_) {
      return defaultCategories;
    }
  }

  Future<void> saveCategories(List<CategoryModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kCategories, raw);
  }

  // --- Wallets ---

  List<WalletModel> getWallets() {
    final raw = _prefs.getString(_kWallets);
    if (raw == null) return defaultWallets;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => WalletModel.fromJson(e)).toList();
    } catch (_) {
      return defaultWallets;
    }
  }

  Future<void> saveWallets(List<WalletModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kWallets, raw);
  }

  // --- Settings ---

  UserSettingsModel getSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const UserSettingsModel();
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return UserSettingsModel.fromJson(decoded);
    } catch (_) {
      return const UserSettingsModel();
    }
  }

  Future<void> saveSettings(UserSettingsModel settings) async {
    final raw = jsonEncode(settings.toJson());
    await _prefs.setString(_kSettings, raw);
  }

  // --- Recurring Rules ---

  List<RecurringRuleModel> getRecurringRules() {
    final raw = _prefs.getString(_kRecurringRules);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => RecurringRuleModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecurringRules(List<RecurringRuleModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kRecurringRules, raw);
  }

  // --- In-App Notifications ---

  List<AppNotificationModel> getNotifications() {
    final raw = _prefs.getString(_kNotifications);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => AppNotificationModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifications(List<AppNotificationModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kNotifications, raw);
  }

  Future<void> addNotification(AppNotificationModel notification) async {
    final current = getNotifications();
    final updated = [notification, ...current];
    await saveNotifications(updated);
  }

  // --- Debts & Loans (Lend & Borrow) ---

  List<DebtModel> getDebts() {
    final raw = _prefs.getString(_kDebts);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => DebtModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDebts(List<DebtModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_kDebts, raw);
  }

  // --- Process Due Recurring Rules ---

  Future<int> processDueRecurringRules() async {
    final rules = getRecurringRules();
    final transactions = getTransactions();
    final notifications = getNotifications();
    final settings = getSettings();
    final now = DateTime.now();

    int generatedCount = 0;
    final List<RecurringRuleModel> updatedRules = [];
    final List<TransactionModel> newTransactions = [];
    final List<AppNotificationModel> newNotifications = [];

    for (final rule in rules) {
      if (!rule.isActive) {
        updatedRules.add(rule);
        continue;
      }

      // Check if current time is on or past the due date
      if (now.isAfter(rule.nextDueDate) ||
          (now.year == rule.nextDueDate.year &&
              now.month == rule.nextDueDate.month &&
              now.day == rule.nextDueDate.day)) {
        // Create the automated transaction
        final newTx = TransactionModel(
          id: const Uuid().v4(),
          title: rule.title,
          amount: rule.amount,
          type: rule.type,
          categoryId: rule.categoryId,
          walletId: rule.walletId,
          date: rule.nextDueDate,
          note: rule.note ?? 'Automated recurring ${rule.templatePreset.displayName}',
          createdAt: now,
        );

        newTransactions.add(newTx);
        generatedCount++;

        // Calculate next due date
        final nextDue = rule.calculateNextDueDateAfter(rule.nextDueDate);
        final updatedRule = rule.copyWith(
          lastCreatedDate: now,
          nextDueDate: nextDue,
        );
        updatedRules.add(updatedRule);

        // Add Notification
        newNotifications.add(
          AppNotificationModel(
            id: const Uuid().v4(),
            title: 'Auto-Logged: ${rule.title}',
            message: 'Recurring ${rule.frequency.name} payment of ${settings.currencySymbol}${rule.amount.toStringAsFixed(2)} was logged automatically.',
            type: NotificationType.recurringCreated,
            createdAt: now,
          ),
        );
      } else {
        updatedRules.add(rule);
      }
    }

    if (generatedCount > 0) {
      await saveTransactions([...newTransactions, ...transactions]);
      await saveRecurringRules(updatedRules);
      await saveNotifications([...newNotifications, ...notifications]);
    }

    return generatedCount;
  }

  // --- Reset Entire Database ---

  Future<void> clearAllData() async {
    await _prefs.remove(_kTransactions);
    await _prefs.remove(_kCategories);
    await _prefs.remove(_kWallets);
    await _prefs.remove(_kSettings);
    await _prefs.remove(_kRecurringRules);
    await _prefs.remove(_kNotifications);
    await _prefs.remove(_kDebts);
    await _seedInitialDataIfNeeded();
  }

  // --- Smart Category Auto-suggestion ---

  String? suggestCategoryForTitle(
    String title,
    List<TransactionModel> pastTransactions,
    List<CategoryModel> categories,
  ) {
    if (title.trim().isEmpty) return null;
    final normalized = title.trim().toLowerCase();

    // 1. Exact match from past transactions
    for (final tx in pastTransactions) {
      if (tx.title.trim().toLowerCase() == normalized) {
        return tx.categoryId;
      }
    }

    // 2. Keyword/substring match from past transactions
    for (final tx in pastTransactions) {
      final pastTitle = tx.title.trim().toLowerCase();
      if (pastTitle.contains(normalized) || normalized.contains(pastTitle)) {
        return tx.categoryId;
      }
    }

    // 3. Keyword heuristic match on default categories
    final Map<String, List<String>> heuristics = {
      'food': ['food', 'lunch', 'dinner', 'breakfast', 'zomato', 'swiggy', 'cafe', 'coffee', 'starbucks', 'mcdonalds', 'kfc', 'burger', 'pizza', 'restaurant'],
      'groceries': ['grocery', 'groceries', 'supermarket', 'blinkit', 'zepto', 'instamart', 'milk', 'vegetables', 'fruits', 'market'],
      'transport': ['uber', 'ola', 'rapido', 'metro', 'bus', 'fuel', 'petrol', 'diesel', 'taxi', 'auto', 'toll', 'parking'],
      'shopping': ['amazon', 'flipkart', 'myntra', 'clothes', 'shoes', 'dress', 'mall', 'electronics', 'purchase'],
      'bills': ['electricity', 'water', 'wifi', 'broadband', 'recharge', 'jio', 'airtel', 'gas', 'bill', 'emi', 'insurance'],
      'rent': ['rent', 'house', 'maintenance', 'landlord'],
      'health': ['pharmacy', 'medicine', 'doctor', 'hospital', 'apollo', 'clinic', 'dentist', 'gym'],
      'entertainment': ['netflix', 'spotify', 'movie', 'cinema', 'theatre', 'prime', 'game', 'gaming', 'ott', 'hotstar'],
      'salary': ['salary', 'paycheck', 'payroll', 'bonus', 'stipend', 'wage'],
      'freelance': ['client', 'project', 'freelance', 'consulting', 'upwork', 'fiverr'],
    };

    for (final entry in heuristics.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) {
          final catExists = categories.any((c) => c.id == entry.key);
          if (catExists) return entry.key;
        }
      }
    }

    return null;
  }

  // --- Seed Initial Mock Data for First Launch Experience ---

  Future<void> _seedInitialDataIfNeeded() async {
    if (_prefs.containsKey(_kCategories)) return;

    await saveTransactions([]);
    await saveCategories(defaultCategories);
    await saveWallets(defaultWallets);
    await saveSettings(const UserSettingsModel());
    await saveRecurringRules([]);
    await saveNotifications([]);
    await saveDebts([]);
  }
}
