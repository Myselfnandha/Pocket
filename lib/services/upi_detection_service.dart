import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/category_model.dart';
import '../models/detected_transaction_model.dart';
import '../models/wallet_model.dart';

class UpiDetectionService {
  static const MethodChannel _channel = MethodChannel('com.pocket.pocket/upi_detector');

  static Function(String deepLink)? onDeepLinkReceived;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLinkReceived') {
        final link = call.arguments as String?;
        if (link != null && onDeepLinkReceived != null) {
          onDeepLinkReceived!(link);
        }
      }
    });
  }

  /// Check if Android's Notification Access setting has been granted for Pocket.
  static Future<bool> isNotificationAccessGranted() async {
    try {
      final granted = await _channel.invokeMethod<bool>('isNotificationAccessGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launch Android's special Notification Access settings page.
  static Future<bool> openNotificationAccessSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openNotificationAccessSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieve all pending payment transactions captured by the background notification listener.
  static Future<List<DetectedTransactionModel>> getPendingDetectedTransactions() async {
    try {
      final jsonStr = await _channel.invokeMethod<String>('getPendingDetectedTransactions');
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => DetectedTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove a transaction from the pending queue after saving or dismissing.
  static Future<void> removePendingDetectedTransaction(String id) async {
    try {
      await _channel.invokeMethod('removePendingDetectedTransaction', {'id': id});
    } catch (_) {}
  }

  /// Clear all pending detected transactions.
  static Future<void> clearAllPendingDetectedTransactions() async {
    try {
      await _channel.invokeMethod('clearAllPendingDetectedTransactions');
    } catch (_) {}
  }

  /// Get initial deep link on app cold start.
  static Future<String?> getInitialDeepLink() async {
    try {
      return await _channel.invokeMethod<String>('getInitialDeepLink');
    } catch (_) {
      return null;
    }
  }

  /// Auto-match source payment app (e.g. Google Pay, PhonePe, HDFC) to an existing user wallet.
  static WalletModel? matchWalletForApp(String sourceApp, List<WalletModel> wallets) {
    if (wallets.isEmpty) return null;

    final appLower = sourceApp.toLowerCase();

    // 1. Exact or direct keyword match
    for (final w in wallets) {
      final nameLower = w.name.toLowerCase();
      if (appLower.contains('google pay') || appLower.contains('gpay')) {
        if (nameLower.contains('gpay') || nameLower.contains('google pay') || nameLower.contains('google')) {
          return w;
        }
      }
      if (appLower.contains('phonepe')) {
        if (nameLower.contains('phonepe') || nameLower.contains('phone pe')) {
          return w;
        }
      }
      if (appLower.contains('paytm')) {
        if (nameLower.contains('paytm')) {
          return w;
        }
      }
      if (appLower.contains('cred')) {
        if (nameLower.contains('cred') || nameLower.contains('credit card') || nameLower.contains('card')) {
          return w;
        }
      }
      if (appLower.contains('hdfc')) {
        if (nameLower.contains('hdfc')) return w;
      }
      if (appLower.contains('sbi')) {
        if (nameLower.contains('sbi') || nameLower.contains('state bank')) return w;
      }
      if (appLower.contains('icici')) {
        if (nameLower.contains('icici')) return w;
      }
      if (appLower.contains('axis')) {
        if (nameLower.contains('axis')) return w;
      }
      if (appLower.contains('kotak')) {
        if (nameLower.contains('kotak')) return w;
      }
    }

    // 2. Generic UPI / Bank type match
    final upiOrBankWallet = wallets.firstWhere(
      (w) => w.walletType == WalletType.bank || w.walletType == WalletType.upi,
      orElse: () => wallets.first,
    );
    return upiOrBankWallet;
  }

  /// Auto-predict category from merchant name using intelligent keyword heuristics.
  static CategoryModel? predictCategoryForMerchant(
    String merchant,
    List<CategoryModel> categories,
  ) {
    if (categories.isEmpty || merchant.isEmpty) return null;

    final m = merchant.toLowerCase();

    // Food & Dining
    if (m.contains('swiggy') || m.contains('zomato') || m.contains('mcdonald') ||
        m.contains('starbucks') || m.contains('domino') || m.contains('kfc') ||
        m.contains('pizza') || m.contains('burger') || m.contains('restaurant') ||
        m.contains('cafe') || m.contains('tea') || m.contains('coffee') ||
        m.contains('bakery') || m.contains('dhaba') || m.contains('bites') ||
        m.contains('food') || m.contains('dining') || m.contains('hotel') ||
        m.contains('eats') || m.contains('canteen') || m.contains('sweets')) {
      return _findCategoryByKeywords(categories, ['food', 'dining', 'restaurant', 'cafe', 'groceries']);
    }

    // Transportation & Fuel
    if (m.contains('uber') || m.contains('ola') || m.contains('rapido') ||
        m.contains('metro') || m.contains('petrol') || m.contains('fuel') ||
        m.contains('shell') || m.contains('indian oil') || m.contains('hp ') ||
        m.contains('bharat petroleum') || m.contains('fastag') || m.contains('toll') ||
        m.contains('parking') || m.contains('taxi') || m.contains('auto') ||
        m.contains('railway') || m.contains('irctc') || m.contains('flight') ||
        m.contains('indigo') || m.contains('air india') || m.contains('bus')) {
      return _findCategoryByKeywords(categories, ['transport', 'fuel', 'travel', 'vehicle']);
    }

    // Shopping & Quick Commerce
    if (m.contains('amazon') || m.contains('flipkart') || m.contains('myntra') ||
        m.contains('meesho') || m.contains('ajio') || m.contains('zara') ||
        m.contains('h&m') || m.contains('dmart') || m.contains('blinkit') ||
        m.contains('zepto') || m.contains('instamart') || m.contains('bigbasket') ||
        m.contains('retail') || m.contains('supermarket') || m.contains('store') ||
        m.contains('mall') || m.contains('trends') || m.contains('reliancedigital') ||
        m.contains('croma') || m.contains('apple')) {
      return _findCategoryByKeywords(categories, ['shopping', 'groceries', 'electronics', 'general']);
    }

    // Entertainment & Subscriptions
    if (m.contains('netflix') || m.contains('spotify') || m.contains('prime') ||
        m.contains('hotstar') || m.contains('youtube') || m.contains('bookmyshow') ||
        m.contains('cinema') || m.contains('pvr') || m.contains('inox') ||
        m.contains('movie') || m.contains('game') || m.contains('steam') ||
        m.contains('playstation') || m.contains('entertainment')) {
      return _findCategoryByKeywords(categories, ['entertainment', 'subscription', 'games', 'leisure']);
    }

    // Utilities & Bills
    if (m.contains('bescom') || m.contains('tneb') || m.contains('electricity') ||
        m.contains('water') || m.contains('gas') || m.contains('broadband') ||
        m.contains('wifi') || m.contains('airtel') || m.contains('jio') ||
        m.contains('vi ') || m.contains('recharge') || m.contains('bill') ||
        m.contains('dth') || m.contains('tatasky') || m.contains('maintenance')) {
      return _findCategoryByKeywords(categories, ['utilities', 'bills', 'recharge', 'services']);
    }

    // Health & Medicine
    if (m.contains('apollo') || m.contains('pharmacy') || m.contains('medplus') ||
        m.contains('1mg') || m.contains('pharmeasy') || m.contains('hospital') ||
        m.contains('clinic') || m.contains('doctor') || m.contains('medicine') ||
        m.contains('diagnostic') || m.contains('lab') || m.contains('health')) {
      return _findCategoryByKeywords(categories, ['health', 'medical', 'medicine', 'wellness']);
    }

    // Salary & Income
    if (m.contains('salary') || m.contains('payroll') || m.contains('bonus') ||
        m.contains('dividend') || m.contains('interest') || m.contains('stipend') ||
        m.contains('payout') || m.contains('freelance') || m.contains('client')) {
      return _findCategoryByKeywords(categories, ['salary', 'income', 'bonus', 'investment']);
    }

    return categories.first;
  }

  static CategoryModel? _findCategoryByKeywords(List<CategoryModel> categories, List<String> keywords) {
    for (final kw in keywords) {
      for (final cat in categories) {
        if (cat.name.toLowerCase().contains(kw)) {
          return cat;
        }
      }
    }
    return categories.isNotEmpty ? categories.first : null;
  }
}
