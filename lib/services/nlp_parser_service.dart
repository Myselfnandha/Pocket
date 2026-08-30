import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class ParsedNlpTransaction {
  final double? amount;
  final String? title;
  final TransactionType type;
  final String? categoryId;
  final String? walletId;
  final DateTime date;
  final String? rawInput;
  final double confidence;

  const ParsedNlpTransaction({
    this.amount,
    this.title,
    this.type = TransactionType.expense,
    this.categoryId,
    this.walletId,
    required this.date,
    this.rawInput,
    this.confidence = 0.8,
  });
}

class NlpTransactionParser {
  /// Parses natural language input like:
  /// - "1200 for dinner with friends yesterday"
  /// - "paid 4500 electricity bill via bank"
  /// - "received 50000 salary from company"
  /// - "spent 85 on coffee at starbucks 2 days ago"
  static ParsedNlpTransaction parse(
    String input, {
    List<CategoryModel> categories = const [],
    List<WalletModel> wallets = const [],
    List<TransactionModel> pastTxs = const [],
  }) {
    if (input.trim().isEmpty) {
      return ParsedNlpTransaction(date: DateTime.now(), rawInput: input, confidence: 0.0);
    }

    final lower = input.toLowerCase().trim();
    double? extractedAmount;
    DateTime extractedDate = DateTime.now();
    TransactionType extractedType = TransactionType.expense;
    String? extractedCategoryId;
    String? extractedWalletId;
    String workingText = lower;

    // 1. Detect Transaction Type (Income vs Expense)
    final incomeKeywords = [
      'salary', 'credited', 'received', 'got', 'earned', 'income',
      'refund', 'cashback', 'dividend', 'deposit', 'bonus', 'interest'
    ];
    if (incomeKeywords.any((kw) => lower.contains(kw))) {
      extractedType = TransactionType.income;
    }

    // 2. Extract Amount
    // Matches ₹1200, 1200rs, 1200.50, 1.5k, rs 1200, usd 50, $50
    final kMultiplierRegex = RegExp(r'(?:₹|\$|rs\.?|inr)?\s*(\d+(?:\.\d+)?)\s*k\b', caseSensitive: false);
    final kMatch = kMultiplierRegex.firstMatch(lower);
    if (kMatch != null) {
      final base = double.tryParse(kMatch.group(1) ?? '0') ?? 0;
      extractedAmount = base * 1000;
      workingText = workingText.replaceFirst(kMatch.group(0)!, ' ');
    } else {
      final amountRegex = RegExp(
        r'(?:(?:₹|\$|rs\.?|inr|usd|aud|eur|gbp)\s*)?(\d+(?:,\d{3})*(?:\.\d{1,2})?)(?:\s*(?:rs\.?|inr|usd|bucks|rupees))?',
        caseSensitive: false,
      );
      final allMatches = amountRegex.allMatches(lower);
      for (final match in allMatches) {
        final matchStr = match.group(1)?.replaceAll(',', '') ?? '';
        final parsed = double.tryParse(matchStr);
        if (parsed != null && parsed > 0) {
          extractedAmount = parsed;
          workingText = workingText.replaceFirst(match.group(0)!, ' ');
          break;
        }
      }
    }

    // 3. Extract Relative or Explicit Date
    final now = DateTime.now();
    if (lower.contains('yesterday')) {
      extractedDate = now.subtract(const Duration(days: 1));
      workingText = workingText.replaceAll('yesterday', ' ');
    } else if (lower.contains('day before yesterday')) {
      extractedDate = now.subtract(const Duration(days: 2));
      workingText = workingText.replaceAll('day before yesterday', ' ');
    } else if (lower.contains('tomorrow')) {
      extractedDate = now.add(const Duration(days: 1));
      workingText = workingText.replaceAll('tomorrow', ' ');
    } else if (lower.contains('today')) {
      extractedDate = now;
      workingText = workingText.replaceAll('today', ' ');
    } else {
      final nDaysAgoRegex = RegExp(r'(\d+)\s*days?\s*ago');
      final daysMatch = nDaysAgoRegex.firstMatch(lower);
      if (daysMatch != null) {
        final days = int.tryParse(daysMatch.group(1) ?? '0') ?? 0;
        extractedDate = now.subtract(Duration(days: days));
        workingText = workingText.replaceFirst(daysMatch.group(0)!, ' ');
      } else {
        // Weekdays (e.g. "on friday", "last monday")
        final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        for (int i = 0; i < weekdays.length; i++) {
          final wd = weekdays[i];
          if (lower.contains(wd)) {
            int targetWeekday = i + 1; // 1 = Monday, 7 = Sunday
            int diff = now.weekday - targetWeekday;
            if (diff <= 0) diff += 7;
            extractedDate = now.subtract(Duration(days: diff));
            workingText = workingText.replaceAll(RegExp('(?:last|on)?\\s*$wd'), ' ');
            break;
          }
        }
      }
    }

    // 4. Extract Wallet
    if (wallets.isNotEmpty) {
      // Pass 1: Check specific account last 4 digits
      for (final w in wallets) {
        if (w.accountNumber != null && w.accountNumber!.isNotEmpty && lower.contains(w.accountNumber!)) {
          extractedWalletId = w.id;
          workingText = workingText.replaceAll(w.accountNumber!, ' ');
          break;
        }
      }

      // Pass 2: Check explicit wallet name & individual word tokens (e.g. "Canara", "Axis", "Salary", "dd")
      if (extractedWalletId == null) {
        const stopWords = {'and', 'the', 'for', 'account', 'in', 'to', 'on', 'at', 'my', 'is', 'an', 'as', 'by', 'of', 'or', 'no', 'up', 'so', 'hand'};
        for (final w in wallets) {
          final nameLower = w.name.toLowerCase().trim();
          if (nameLower.length >= 2 && RegExp(r'\b' + RegExp.escape(nameLower) + r'\b').hasMatch(lower)) {
            extractedWalletId = w.id;
            workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(nameLower) + r'\b'), ' ');
            break;
          }
          final tokens = nameLower.split(RegExp(r'\s+')).where((t) => t.length >= 2);
          for (final token in tokens) {
            if (!stopWords.contains(token) && RegExp(r'\b' + RegExp.escape(token) + r'\b').hasMatch(lower)) {
              extractedWalletId = w.id;
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(token) + r'\b'), ' ');
              break;
            }
          }
          if (extractedWalletId != null) break;
        }
      }

      // Pass 3: Check wallet type keywords (e.g. "bank account", "bank", "cash", "upi", "card", "savings")
      if (extractedWalletId == null) {
        final bankKeywords = ['bank account', 'bank', 'neft', 'rtgs', 'imps', 'transfer', 'hdfc', 'sbi', 'icici', 'axis', 'kotak', 'pnb'];
        final upiKeywords = ['upi', 'gpay', 'google pay', 'phonepe', 'paytm', 'bhim', 'qr'];
        final cardKeywords = ['credit card', 'debit card', 'card', 'visa', 'mastercard', 'amex'];
        final cashKeywords = ['cash in hand', 'cash', 'hard cash', 'physical cash'];
        final savingsKeywords = ['savings', 'vault', 'emergency fund'];

        bool matchesKeywords(List<String> keywords) {
          return keywords.any((kw) => RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lower));
        }

        if (matchesKeywords(bankKeywords)) {
          final bankWallet = wallets.where((w) => w.walletType == WalletType.bank).firstOrNull;
          if (bankWallet != null) {
            extractedWalletId = bankWallet.id;
            for (final kw in bankKeywords) {
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(kw) + r'\b'), ' ');
            }
          }
        } else if (matchesKeywords(upiKeywords)) {
          final upiWallet = wallets.where((w) => w.walletType == WalletType.upi).firstOrNull;
          if (upiWallet != null) {
            extractedWalletId = upiWallet.id;
            for (final kw in upiKeywords) {
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(kw) + r'\b'), ' ');
            }
          }
        } else if (matchesKeywords(cardKeywords)) {
          final cardWallet = wallets.where((w) => w.walletType == WalletType.creditCard).firstOrNull;
          if (cardWallet != null) {
            extractedWalletId = cardWallet.id;
            for (final kw in cardKeywords) {
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(kw) + r'\b'), ' ');
            }
          }
        } else if (matchesKeywords(cashKeywords)) {
          final cashWallet = wallets.where((w) => w.walletType == WalletType.cash).firstOrNull;
          if (cashWallet != null) {
            extractedWalletId = cashWallet.id;
            for (final kw in cashKeywords) {
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(kw) + r'\b'), ' ');
            }
          }
        } else if (matchesKeywords(savingsKeywords)) {
          final savingsWallet = wallets.where((w) => w.walletType == WalletType.savings).firstOrNull;
          if (savingsWallet != null) {
            extractedWalletId = savingsWallet.id;
            for (final kw in savingsKeywords) {
              workingText = workingText.replaceAll(RegExp(r'(?:via|from|using|in|through|to)?\s*\b' + RegExp.escape(kw) + r'\b'), ' ');
            }
          }
        }
      }
    }

    // 5. Category Keyword Mapping & Matching
    final categoryKeywords = {
      'food': ['dinner', 'lunch', 'breakfast', 'food', 'coffee', 'starbucks', 'zomato', 'swiggy', 'mcdonald', 'kfc', 'burger', 'pizza', 'restaurant', 'cafe', 'groceries', 'snack', 'drink', 'beverage', 'tea', 'chai', 'biryani'],
      'shopping': ['shopping', 'amazon', 'flipkart', 'myntra', 'clothes', 'dress', 'shirt', 'shoes', 'electronics', 'purchase', 'mall', 'zara', 'h&m'],
      'transport': ['uber', 'ola', 'rapido', 'taxi', 'cab', 'ride', 'metro', 'bus', 'train', 'flight', 'petrol', 'fuel', 'diesel', 'auto', 'toll', 'parking'],
      'bills': ['electricity', 'water', 'gas', 'broadband', 'wifi', 'internet', 'bill', 'recharge', 'airtel', 'jio', 'vi', 'emi', 'loan'],
      'entertainment': ['movie', 'cinema', 'pvr', 'netflix', 'prime', 'spotify', 'hotstar', 'game', 'gaming', 'concert', 'theatre', 'show', 'party'],
      'health': ['medicine', 'pharmacy', 'doctor', 'clinic', 'hospital', 'apollo', 'medical', 'gym', 'fitness', 'workout', 'supplements', 'dentist'],
      'salary': ['salary', 'stipend', 'payroll', 'wages', 'client payment', 'freelance'],
      'rent': ['rent', 'landlord', 'room rent', 'flat rent', 'hostel fee', 'maintenance fee'],
      'investment': ['stocks', 'crypto', 'mutual fund', 'sip', 'gold', 'shares', 'bitcoin', 'investment'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          if (categories.isNotEmpty) {
            final matched = categories.firstWhere(
              (c) => c.id == entry.key || c.name.toLowerCase() == entry.key,
              orElse: () => categories.firstWhere(
                (c) => c.name.toLowerCase().contains(entry.key),
                orElse: () => categories.first,
              ),
            );
            extractedCategoryId = matched.id;
          } else {
            extractedCategoryId = entry.key;
          }
          break;
        }
      }
      if (extractedCategoryId != null) break;
    }

    // 6. Clean Title / Description
    // Remove filler prepositions like "for", "paid", "spent", "on", "at", "via", "with", "from", "through", "account", "bank"
    String cleanTitle = workingText
        .replaceAll(RegExp(r'\b(spent|paid|bought|for|on|at|via|using|from|through|with|received|got|earned|credited|to|in|by|account|bank|cash|upi|card|rs|inr|usd|bucks|yesterday|today|tomorrow)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanTitle.isEmpty) {
      if (extractedCategoryId != null && categories.isNotEmpty) {
        final cat = categories.firstWhere((c) => c.id == extractedCategoryId, orElse: () => categories.first);
        cleanTitle = cat.name;
      } else {
        cleanTitle = extractedType == TransactionType.income ? 'Income Entry' : 'Expense Entry';
      }
    } else {
      // Capitalize first letter of each word
      cleanTitle = cleanTitle.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }

    // Calculate parsing confidence score
    double confidence = 0.5;
    if (extractedAmount != null && extractedAmount > 0) confidence += 0.25;
    if (extractedCategoryId != null) confidence += 0.15;
    if (extractedWalletId != null) confidence += 0.10;

    return ParsedNlpTransaction(
      amount: extractedAmount,
      title: cleanTitle,
      type: extractedType,
      categoryId: extractedCategoryId,
      walletId: extractedWalletId,
      date: extractedDate,
      rawInput: input,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }
}
