import 'dart:convert';
import 'package:flutter/foundation.dart';

class UpiParsedTransaction {
  final double? amount;
  final String merchant;
  final String appSource;
  final String? refId;
  final String? imagePath;
  final String? rawText;
  final String? suggestedCategoryId;
  final DateTime date;

  const UpiParsedTransaction({
    this.amount,
    required this.merchant,
    this.appSource = 'UPI App',
    this.refId,
    this.imagePath,
    this.rawText,
    this.suggestedCategoryId,
    required this.date,
  });

  factory UpiParsedTransaction.fromJson(Map<String, dynamic> json) {
    double? parsedAmount;
    final amtVal = json['amount'];
    if (amtVal != null) {
      if (amtVal is num) {
        parsedAmount = amtVal.toDouble();
      } else if (amtVal is String) {
        parsedAmount = double.tryParse(amtVal.replaceAll(',', '').trim());
      }
    }

    final merchant = (json['merchant'] as String?)?.trim() ?? 'UPI Transaction';
    final appSource = (json['app_source'] as String?)?.trim() ?? 'UPI App';
    final refId = (json['ref_id'] as String?)?.trim();
    final imagePath = (json['image_path'] as String?)?.trim();
    final rawText = (json['raw_text'] as String?)?.trim();

    return UpiParsedTransaction(
      amount: (parsedAmount != null && parsedAmount > 0) ? parsedAmount : null,
      merchant: merchant.isNotEmpty ? merchant : 'UPI Payment',
      appSource: appSource.isNotEmpty ? appSource : 'UPI App',
      refId: (refId != null && refId.isNotEmpty) ? refId : null,
      imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
      rawText: rawText,
      suggestedCategoryId: UpiScreenshotParserService.predictCategory(merchant, rawText ?? ''),
      date: DateTime.now(),
    );
  }

  factory UpiParsedTransaction.fromPayloadString(String jsonString) {
    try {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      return UpiParsedTransaction.fromJson(map);
    } catch (e) {
      debugPrint('Error decoding UpiParsedTransaction: $e');
      return UpiParsedTransaction(
        merchant: 'UPI Payment',
        date: DateTime.now(),
      );
    }
  }

  @override
  String toString() =>
      'UpiParsedTransaction(amount: $amount, merchant: $merchant, app: $appSource, ref: $refId, image: $imagePath)';
}

class UpiScreenshotParserService {
  /// Matches merchant keywords to default categories
  static String predictCategory(String merchant, String rawText) {
    final combined = '$merchant $rawText'.toLowerCase();

    // Food & Dining
    if (RegExp(r'\b(zomato|swiggy|mcdonalds|dominos|kfc|starbucks|burger|restaurant|cafe|bakery|dhabha|food|dining|pizza|tea|coffee)\b')
        .hasMatch(combined)) {
      return 'cat_food';
    }

    // Groceries
    if (RegExp(r'\b(blinkit|zepto|instamart|bigbasket|dmart|supermarket|grocery|groceries|spencer|nature basket)\b')
        .hasMatch(combined)) {
      return 'cat_groceries';
    }

    // Shopping
    if (RegExp(r'\b(amazon|flipkart|myntra|ajio|meesho|nykaa|zara|h&m|shopping|retail|store|mart)\b')
        .hasMatch(combined)) {
      return 'cat_shopping';
    }

    // Transport & Fuel
    if (RegExp(r'\b(uber|ola|rapido|petrol|fuel|hpcl|bpcl|ioc|diesel|metro|irctc|redbus|flight|indigo|transport)\b')
        .hasMatch(combined)) {
      return 'cat_transport';
    }

    // Entertainment
    if (RegExp(r'\b(bookmyshow|netflix|prime|hotstar|spotify|cinema|movie|gaming|steam|playstation)\b')
        .hasMatch(combined)) {
      return 'cat_entertainment';
    }

    // Bills & Utilities
    if (RegExp(r'\b(bescom|electricity|water|gas|wifi|broadband|airtel|jio|vi|recharge|dth|bill)\b')
        .hasMatch(combined)) {
      return 'cat_bills';
    }

    // Health & Medical
    if (RegExp(r'\b(apollo|pharmacy|medplus|1mg|practo|hospital|clinic|doctor|pharma|lab|dental)\b')
        .hasMatch(combined)) {
      return 'cat_health';
    }

    // Fallback: Default to Other or General
    return 'cat_other';
  }
}
