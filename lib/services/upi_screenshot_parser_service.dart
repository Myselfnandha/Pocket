import 'dart:convert';
import 'package:flutter/foundation.dart';

class UpiParsedTransaction {
  final String? id;
  final double? amount;
  final String merchant;
  final String appSource;
  final String? refId;
  final String? imagePath;
  final String? rawText;
  final String? suggestedCategoryId;
  final String? senderName;
  final String? receiverName;
  final String? counterpartyLast4;
  final bool isIncome;
  final bool autoSaveDirect;
  final DateTime date;

  const UpiParsedTransaction({
    this.id,
    this.amount,
    required this.merchant,
    this.appSource = 'UPI App',
    this.refId,
    this.imagePath,
    this.rawText,
    this.suggestedCategoryId,
    this.senderName,
    this.receiverName,
    this.counterpartyLast4,
    this.isIncome = false,
    this.autoSaveDirect = false,
    required this.date,
  });

  factory UpiParsedTransaction.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    final autoSaveDirect = json['auto_save_direct'] == true || json['autoSaveDirect'] == true;

    double? parsedAmount;
    final amtVal = json['amount'];
    if (amtVal != null) {
      if (amtVal is num) {
        parsedAmount = amtVal.toDouble();
      } else if (amtVal is String) {
        parsedAmount = double.tryParse(amtVal.replaceAll(',', '').trim());
      }
    }

    final rawText = (json['raw_text'] as String?)?.trim();

    // Fallback amount extraction from raw OCR text if Kotlin parsing was null/0
    if (parsedAmount == null || parsedAmount <= 0) {
      if (rawText != null && rawText.isNotEmpty) {
        parsedAmount = UpiScreenshotParserService.extractAmount(rawText);
      }
    }

    var merchant = (json['merchant'] as String?)?.trim() ?? 'UPI Transaction';
    final appSource = (json['app_source'] as String?)?.trim() ?? 'UPI App';
    var refId = (json['ref_id'] as String?)?.trim();
    final imagePath = (json['image_path'] as String?)?.trim();
    var senderName = (json['sender_name'] as String?)?.trim();
    var receiverName = (json['receiver_name'] as String?)?.trim();
    var counterpartyLast4 = (json['counterparty_last4'] as String?)?.trim();
    bool isIncome = json['is_income'] == true;

    if (refId == null || refId.isEmpty) {
      if (rawText != null && rawText.isNotEmpty) {
        refId = UpiScreenshotParserService.extractRefId(rawText);
      }
    }

    if (rawText != null && rawText.isNotEmpty) {
      senderName ??= UpiScreenshotParserService.extractSender(rawText);
      receiverName ??= UpiScreenshotParserService.extractReceiver(rawText);
      counterpartyLast4 ??= UpiScreenshotParserService.extractLast4(rawText);
      if (!isIncome) {
        isIncome = UpiScreenshotParserService.detectIsIncome(rawText);
      }
    }

    if (merchant.isEmpty || merchant == 'UPI Transaction' || merchant == 'UPI Payment') {
      if (isIncome && senderName != null && senderName.isNotEmpty) {
        merchant = senderName;
      } else if (receiverName != null && receiverName.isNotEmpty) {
        merchant = receiverName;
      }
    }

    return UpiParsedTransaction(
      id: id,
      amount: (parsedAmount != null && parsedAmount > 0) ? parsedAmount : null,
      merchant: merchant.isNotEmpty ? merchant : 'UPI Payment',
      appSource: appSource.isNotEmpty ? appSource : 'UPI App',
      refId: (refId != null && refId.isNotEmpty) ? refId : null,
      imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
      rawText: rawText,
      suggestedCategoryId: UpiScreenshotParserService.predictCategory(merchant, rawText ?? ''),
      senderName: (senderName != null && senderName.isNotEmpty) ? senderName : null,
      receiverName: (receiverName != null && receiverName.isNotEmpty) ? receiverName : null,
      counterpartyLast4: (counterpartyLast4 != null && counterpartyLast4.isNotEmpty) ? counterpartyLast4 : null,
      isIncome: isIncome,
      autoSaveDirect: autoSaveDirect,
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
      'UpiParsedTransaction(id: $id, amount: $amount, merchant: $merchant, app: $appSource, ref: $refId, sender: $senderName, receiver: $receiverName, last4: $counterpartyLast4, isIncome: $isIncome, autoSave: $autoSaveDirect, image: $imagePath)';
}

class UpiScreenshotParserService {
  /// Robust multi-pattern Amount Extractor
  static double? extractAmount(String rawText) {
    final text = rawText.replaceAll('\u00A0', ' ');

    // 1. Explicit Currency and Transaction verbs
    final patterns = [
      RegExp(r'(?:[₹\u20B9*?=]|Rs\.?|INR|\$)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:Paid|Payment of|Sent|Transferred|Amount|Total|Debited|Debited by|Spent|Received)\s*(?:[₹\u20B9*?=]|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:[₹\u20B9]|INR|Rs)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final candidate = match.group(1)?.replaceAll(',', '').trim() ?? '';
        final val = double.tryParse(candidate);
        if (val != null && val > 0 && val < 10000000) {
          return val;
        }
      }
    }

    // 2. Line-by-Line Contextual Scanner (e.g. ₹ on line 1, 450.00 or 500 on line 2)
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineMatch = RegExp(r'^[₹\u20B9*?=\sRsINR]*([0-9,]+(?:\.[0-9]{1,2})?)\s*$', caseSensitive: false).firstMatch(line);
      if (lineMatch != null) {
        final candidate = lineMatch.group(1)?.replaceAll(',', '').trim() ?? '';
        final val = double.tryParse(candidate);
        if (val != null && val > 0 && val < 10000000) {
          final prevLine = (i > 0) ? lines[i - 1].toLowerCase() : '';
          final nextLine = (i < lines.length - 1) ? lines[i + 1].toLowerCase() : '';
          final isNearContext = prevLine.contains('paid') || prevLine.contains('sent') ||
              prevLine.contains('received') || prevLine.contains('amount') ||
              prevLine.contains('successful') || prevLine.contains('completed') ||
              nextLine.contains('completed') || nextLine.contains('successful') ||
              line.contains('₹') || prevLine.contains('₹');

          if (isNearContext) {
            return val;
          }
        }
      }
    }

    // 3. Fallback: Largest monetary decimal on screen (e.g. 500.00)
    final decimalMatches = RegExp(r'\b([0-9]{1,6}\.[0-9]{2})\b').allMatches(text);
    double maxCandidate = 0;
    for (final m in decimalMatches) {
      final candidate = m.group(1) ?? '';
      final val = double.tryParse(candidate);
      if (val != null && val > 0 && val < 10000000 && val > maxCandidate) {
        maxCandidate = val;
      }
    }
    if (maxCandidate > 0) return maxCandidate;

    return null;
  }

  /// Robust Reference / UTR Number Extractor
  static String? extractRefId(String text) {
    final refPatterns = [
      RegExp(r'(?:UPI\s*(?:Ref(?:erence)?|Txn|Transaction)?\s*(?:No|ID|Num)?[:\s]*|UTR[:\s]*|Txn\s*ID[:\s]*|Transaction\s*ID[:\s]*|Ref\s*(?:No|ID)?[:\s]*|Google transaction ID[:\s]*|PhonePe transaction ID[:\s]*)([0-9A-Za-z]{8,24})', caseSensitive: false),
      RegExp(r'\b([0-9]{12})\b'),
    ];

    for (final pattern in refPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final candidate = match.group(1)?.trim() ?? '';
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Extracts Sender / Payer Name (Multi-line aware)
  static String? extractSender(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l == 'received from' || l == 'from:' || l == 'from' || l == 'payer:') {
        if (i + 1 < lines.length) {
          final candidate = cleanMerchantCandidate(lines[i + 1]);
          if (candidate.isNotEmpty && !isTechnicalKeyword(candidate)) {
            return candidate;
          }
        }
      }
    }

    final sentYouMatch = RegExp(r'([A-Za-z0-9\s&.\-_]{2,30})\s+sent you', caseSensitive: false).firstMatch(text);
    if (sentYouMatch != null) {
      final found = cleanMerchantCandidate(sentYouMatch.group(1) ?? '');
      if (found.isNotEmpty && !isTechnicalKeyword(found)) {
        return found;
      }
    }

    final patterns = [
      RegExp(r'(?:Received from|From:|Sent by|Payer:|Paid by|Transferred from)\s+([A-Za-z0-9\s&.\-_]{2,35})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final candidate = cleanMerchantCandidate(m.group(1) ?? '');
        if (candidate.isNotEmpty && !isTechnicalKeyword(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Extracts Receiver / Payee Name (Multi-line aware)
  static String? extractReceiver(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l == 'paid to' || l == 'to:' || l == 'to' || l == 'payment to' || l == 'sent to' || l == 'transfer to') {
        if (i + 1 < lines.length) {
          final candidate = cleanMerchantCandidate(lines[i + 1]);
          if (candidate.isNotEmpty && !isTechnicalKeyword(candidate)) {
            return candidate;
          }
        }
      }
    }

    final patterns = [
      RegExp(r'(?:Paid to|To:|Sent to|Transfer to|Payment to|Payee:)\s+([A-Za-z0-9\s&.\-_]{2,35})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final candidate = cleanMerchantCandidate(m.group(1) ?? '');
        if (candidate.isNotEmpty && !isTechnicalKeyword(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Extracts Last 4 digits of phone number or bank account
  static String? extractLast4(String text) {
    // 1. Phone numbers with +91 or 10-digits (including spaces and dashes: +91 98765 43210, 98765-43210)
    final phoneMatch = RegExp(r'(?:\+?91[\s\-]*)?[6-9]\d{4}[\s\-]?\d{4,5}\b').firstMatch(text) ??
        RegExp(r'(?:\+?91[\s\-]*)?[6-9]\d{2}[\s\-]?\d{3}[\s\-]?\d{4}\b').firstMatch(text) ??
        RegExp(r'\b[6-9]\d{9}\b').firstMatch(text);
    if (phoneMatch != null) {
      final digits = phoneMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        return digits.substring(digits.length - 4);
      }
    }

    // 2. Masked Account / Card (e.g. A/c ...1234 or XX5678 or •••• 1234)
    final acctMatch = RegExp(r'(?:A/c|Account|Card|Bank)?\s*(?:[xX*•]+|\.{2,})\s*(\d{4})\b', caseSensitive: false).firstMatch(text);
    if (acctMatch != null) {
      return acctMatch.group(1);
    }

    return null;
  }

  /// Detects whether transaction is Income (Received / Credited)
  static bool detectIsIncome(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('received from') || lower.contains('money received') || lower.contains('credited to') || lower.contains('credited') || lower.contains('sent you')) {
      return true;
    }
    if (lower.contains('deposit') || lower.contains('cashback') || lower.contains('refund')) {
      return true;
    }
    if (lower.contains('received') && !lower.contains('debited')) {
      return true;
    }
    return false;
  }

  static String cleanMerchantCandidate(String candidate) {
    return candidate.split(RegExp(r'[\r\n]+')).firstOrNull?.trim()
            .replaceAll(RegExp(r'@ok[a-z]+|@okhdfcbank|@axisbank|@ybl|@ibl|@paytm|@upi|@axl', caseSensitive: false), '')
            .replaceAll(RegExp(r'\b(completed|successful|paid|to|ref|no|verified merchant|google pay|phonepe|banking name|upi id)\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '')
            .trim() ?? '';
  }

  static bool isTechnicalKeyword(String word) {
    final lower = word.toLowerCase();
    return const {'completed', 'successful', 'upi', 'banking', 'account', 'ref', 'details', 'transfer', 'payment', 'rupees', 'rs'}.contains(lower);
  }

  /// Matches merchant keywords to default categories
  static String predictCategory(String merchant, String rawText) {
    final combined = '$merchant $rawText'.toLowerCase();

    // Food & Dining
    if (RegExp(r'\b(zomato|swiggy|mcdonalds|dominos|kfc|starbucks|burger|restaurant|cafe|bakery|dhabha|food|dining|pizza|tea|coffee|biryani|subway)\b')
        .hasMatch(combined)) {
      return 'cat_food';
    }

    // Groceries
    if (RegExp(r'\b(blinkit|zepto|instamart|bigbasket|supermarket|kirana|vegetable|fruits|grocery|groceries|mart|store|dmart|spencer)\b')
        .hasMatch(combined)) {
      return 'cat_groceries';
    }

    // Transport & Fuel
    if (RegExp(r'\b(uber|ola|rapido|metro|petrol|diesel|fuel|hpcl|bpcl|ioc|indian oil|auto|cab|toll|fastag|parking)\b')
        .hasMatch(combined)) {
      return 'cat_transport';
    }

    // Shopping & E-Commerce
    if (RegExp(r'\b(amazon|flipkart|myntra|ajio|meesho|nykaa|shopping|cloth|apparel|retail|mall)\b')
        .hasMatch(combined)) {
      return 'cat_shopping';
    }

    // Entertainment & Subscriptions
    if (RegExp(r'\b(netflix|spotify|hotstar|prime|youtube|cinema|movie|pvr|inox|bookmyshow|steam|playstation)\b')
        .hasMatch(combined)) {
      return 'cat_entertainment';
    }

    // Utilities & Bills
    if (RegExp(r'\b(electricity|bescom|water|gas|broadband|wifi|jio|airtel|vi|recharge|bill|cylinder|postpaid)\b')
        .hasMatch(combined)) {
      return 'cat_bills';
    }

    // Health & Fitness
    if (RegExp(r'\b(pharmacy|apollo|medplus|pharmeasy|hospital|clinic|doctor|gym|fitness|cult|medicine)\b')
        .hasMatch(combined)) {
      return 'cat_health';
    }

    return 'cat_others';
  }
}
