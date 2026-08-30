import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class LearningSuggestService {
  static const String _kLearnedMerchantsKey = 'pocket_learned_merchant_categories';
  static final Map<String, String> _memoryCache = {};
  static bool _isLoaded = false;

  /// Loads learned merchant-to-category associations
  static Future<void> init([SharedPreferences? prefs]) async {
    if (_isLoaded) return;
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString(_kLearnedMerchantsKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _memoryCache.clear();
        decoded.forEach((key, value) {
          _memoryCache[key.toLowerCase()] = value.toString();
        });
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('LearningSuggestService init notice: $e');
    }
  }

  /// Learns and associates a merchant title pattern with a chosen category
  static Future<void> recordCorrection({
    required String merchantTitle,
    required String categoryId,
    SharedPreferences? prefs,
  }) async {
    final clean = _normalizeMerchant(merchantTitle);
    if (clean.isEmpty) return;

    _memoryCache[clean] = categoryId;

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(_kLearnedMerchantsKey, jsonEncode(_memoryCache));
    } catch (e) {
      debugPrint('LearningSuggestService save error: $e');
    }
  }

  /// Suggests a category based on learned merchant memory or transaction history
  static String? suggestCategory({
    required String title,
    required List<CategoryModel> categories,
    List<TransactionModel> pastTransactions = const [],
  }) {
    if (title.trim().isEmpty) return null;
    final clean = _normalizeMerchant(title);

    // 1. Check exact learned merchant cache
    if (_memoryCache.containsKey(clean)) {
      final catId = _memoryCache[clean]!;
      if (categories.any((c) => c.id == catId)) {
        return catId;
      }
    }

    // 2. Check substring & word token learned merchant cache
    final titleTokens = clean.split(' ').where((w) => w.length >= 3).toList();
    for (final entry in _memoryCache.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        if (categories.any((c) => c.id == entry.value)) {
          return entry.value;
        }
      }
      final keyTokens = entry.key.split(' ').where((w) => w.length >= 3).toList();
      for (final t in titleTokens) {
        if (keyTokens.contains(t) || entry.key.contains(t)) {
          if (categories.any((c) => c.id == entry.value)) {
            return entry.value;
          }
        }
      }
    }

    // 3. Check past transaction titles & tokens
    for (final tx in pastTransactions) {
      final txClean = _normalizeMerchant(tx.title);
      if (txClean == clean || clean.contains(txClean) || txClean.contains(clean)) {
        if (categories.any((c) => c.id == tx.categoryId)) {
          return tx.categoryId;
        }
      }
      final txTokens = txClean.split(' ').where((w) => w.length >= 3).toList();
      for (final t in titleTokens) {
        if (txTokens.contains(t)) {
          if (categories.any((c) => c.id == tx.categoryId)) {
            return tx.categoryId;
          }
        }
      }
    }

    return null;
  }

  static String _normalizeMerchant(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @visibleForTesting
  static void clearMemoryForTesting() {
    _memoryCache.clear();
    _isLoaded = false;
  }
}
