import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';

class StorageService {
  static const _kTransactions = 'pocket_transactions';
  static const _kCategories = 'pocket_categories';
  static const _kWallets = 'pocket_wallets';
  static const _kSettings = 'pocket_settings';

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
      'utilities': ['electricity', 'water', 'wifi', 'broadband', 'recharge', 'jio', 'airtel', 'gas', 'bill'],
      'rent': ['rent', 'house', 'maintenance', 'landlord'],
      'health': ['pharmacy', 'medicine', 'doctor', 'hospital', 'apollo', 'clinic', 'dentist', 'gym'],
      'entertainment': ['netflix', 'spotify', 'movie', 'cinema', 'theatre', 'prime', 'game', 'gaming'],
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
  }
}
