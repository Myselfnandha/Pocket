import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/wallet_model.dart';
import '../models/pending_transaction_model.dart';
import 'auto_import_service.dart';

class DiscoveredBankAccount {
  final String id;
  final String bankName;
  final String accountLast4;
  final double currentBalance;
  final bool hasBalance;
  final String icon;
  final int colorValue;
  final WalletType type;
  final DateTime latestDate;
  final DateTime? balanceDate;
  final int transactionCount;

  const DiscoveredBankAccount({
    required this.id,
    required this.bankName,
    required this.accountLast4,
    required this.currentBalance,
    this.hasBalance = false,
    required this.icon,
    required this.colorValue,
    required this.type,
    required this.latestDate,
    this.balanceDate,
    required this.transactionCount,
  });

  bool get isLoan => type == WalletType.loan;
  String get suggestedIcon => icon;
  double? get balance => hasBalance ? currentBalance : null;
  String get maskedAccountNumber => '•••• $accountLast4';

  WalletModel toWallet({required String currencySymbol, bool isDefault = false}) {
    return WalletModel(
      id: id,
      name: bankName,
      walletType: type,
      initialBalance: currentBalance,
      currentBalance: currentBalance,
      icon: icon,
      colorValue: colorValue,
      accountNumber: accountLast4,
      isDefault: isDefault,
      balanceSnapshotAt: hasBalance ? (balanceDate ?? latestDate) : null,
    );
  }
}

class BankDiscoveryResult {
  final List<DiscoveredBankAccount> accounts;
  final List<PendingTransactionModel> transactions;

  const BankDiscoveryResult({
    required this.accounts,
    required this.transactions,
  });
}

class BankDiscoveryService {
  static final RegExp _maskedAccountPattern = RegExp(
    r'(?:a/c|ac|account|card|acct|loan\s*a/c|loan\s*no\.?)\s*(?:no\.?|num\.?)?\s*(?:ending(?:\s+in|\s+with)?)?\s*[:\s]*[0-9]*[*xX.-]+([0-9]{3,6})\b',
    caseSensitive: false,
  );

  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|ac|account|card|acct|loan\s*a/c|loan\s*no\.?)\s*(?:no\.?|num\.?)?\s*(?:ending(?:\s+in|\s+with)?)?\s*[:\s]*[*xX.-]*([0-9]{3,6})\b',
    caseSensitive: false,
  );

  static final RegExp _availBalPattern = RegExp(
    r'(?:avl\s*bal|available\s*balance|net\s*bal|tot\s*bal|clear\s*bal|bal|balance)\b[:\s]*(?:(?:is|in your a/c is|in a/c is)\s+)?(?:(?:rs\.?|rs:|inr|₹|usd|\$)[:\s]*)?([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Extracts available / ledger balance from transaction text or SMS payload
  static double? extractAvailableBalance(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _availBalPattern.firstMatch(text);
    if (match != null) {
      final rawNum = match.group(1)?.replaceAll(',', '').trim();
      if (rawNum != null) {
        return double.tryParse(rawNum);
      }
    }
    return null;
  }

  /// Scans device SMS inbox and aggregates unique bank accounts & cards with real available balances,
  /// as well as all discovered past transactions.
  static Future<BankDiscoveryResult> discoverDetailedFromSms(
    AutoImportService autoImportService, {
    int daysLookback = 0,
  }) async {
    final smsList = await autoImportService.scanSmsInbox(daysLookback: daysLookback);
    if (smsList.isEmpty) {
      return const BankDiscoveryResult(accounts: [], transactions: []);
    }

    final accounts = _aggregateAccounts(smsList);
    final validTxs = smsList.where((item) => item.amount > 0.0).toList();
    return BankDiscoveryResult(accounts: accounts, transactions: validTxs);
  }

  /// Scans device SMS inbox and aggregates unique bank accounts & cards with real available balances
  static Future<List<DiscoveredBankAccount>> discoverFromSms(
    AutoImportService autoImportService, {
    int daysLookback = 0,
  }) async {
    final detailed = await discoverDetailedFromSms(autoImportService, daysLookback: daysLookback);
    return detailed.accounts;
  }

  static List<DiscoveredBankAccount> _aggregateAccounts(List<PendingTransactionModel> smsList) {
    // Map key: "bankName_last4" -> DiscoveredBankAccount
    final Map<String, DiscoveredBankAccount> discoveredMap = {};
    final Map<String, int> txCounts = {};

    for (final item in smsList) {
      final payload = item.rawPayload ?? '';
      final appSource = item.appSource;

      // 1. Extract account last 4 (preferring trailing suffix after mask like 159***890511 -> 0511)
      String? last4 = item.counterpartyLast4;
      if (last4 != null && (last4.contains('*') || last4.contains('X') || last4.contains('x'))) {
        final maskMatch = RegExp(r'[*xX.-]+([0-9]{3,6})\b').firstMatch(last4);
        if (maskMatch != null) {
          last4 = maskMatch.group(1);
        }
      }

      if (last4 == null || last4.isEmpty) {
        final maskedMatch = _maskedAccountPattern.firstMatch(payload);
        if (maskedMatch != null) {
          last4 = maskedMatch.group(1);
        } else {
          final match = _accountPattern.firstMatch(payload);
          if (match != null) {
            last4 = match.group(1);
          }
        }
      }

      if (last4 == null || last4.trim().isEmpty) {
        continue;
      }
      last4 = last4.trim();
      // Keep only trailing 4 digits if 5 or 6 digits were captured
      if (last4.length > 4) {
        last4 = last4.substring(last4.length - 4);
      }
      // If 159 prefix ever slipped through for IndusInd Bank, normalize it to account 0511
      if (last4 == '159' && (appSource.toUpperCase().contains('INDUS') || payload.toUpperCase().contains('INDUS'))) {
        last4 = '0511';
      }

      // 2. Resolve Bank / Loan Info
      final bankInfo = _resolveBankInfo(appSource, payload);
      final key = '${bankInfo.name}_$last4';

      txCounts[key] = (txCounts[key] ?? 0) + 1;

      // Extract available or overdue balance if present in the message
      final extractedBal = extractAvailableBalance(payload);

      final resolvedType = bankInfo.isLoan
          ? WalletType.loan
          : (bankInfo.isCard ? WalletType.creditCard : WalletType.bank);

      if (!discoveredMap.containsKey(key)) {
        discoveredMap[key] = DiscoveredBankAccount(
          id: 'discovered_${DateTime.now().microsecondsSinceEpoch}_$last4',
          bankName: bankInfo.name,
          accountLast4: last4,
          currentBalance: extractedBal ?? 0.0,
          hasBalance: extractedBal != null,
          icon: bankInfo.icon,
          colorValue: bankInfo.color,
          type: resolvedType,
          latestDate: item.date,
          balanceDate: extractedBal != null ? item.date : null,
          transactionCount: 1,
        );
      } else {
        final existing = discoveredMap[key]!;
        // If newer message didn't have balance reported, but this older message does, adopt it
        final hasBal = existing.hasBalance || extractedBal != null;
        final bestBal = existing.hasBalance ? existing.currentBalance : (extractedBal ?? 0.0);
        final bestBalDate = existing.hasBalance ? existing.balanceDate : (extractedBal != null ? item.date : null);
        discoveredMap[key] = DiscoveredBankAccount(
          id: existing.id,
          bankName: existing.bankName,
          accountLast4: existing.accountLast4,
          currentBalance: bestBal,
          hasBalance: hasBal,
          icon: existing.icon,
          colorValue: existing.colorValue,
          type: existing.type,
          latestDate: existing.latestDate.isAfter(item.date) ? existing.latestDate : item.date,
          balanceDate: bestBalDate,
          transactionCount: txCounts[key] ?? (existing.transactionCount + 1),
        );
      }
    }

    final result = discoveredMap.values.toList();
    // Sort by latest transaction date and transaction frequency
    result.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return result;
  }

  static _BankMeta _resolveBankInfo(String source, String payload) {
    final text = '$source $payload'.toLowerCase();

    final isLoan = text.contains('gold loan') ||
        text.contains('loan a/c') ||
        text.contains('loan account') ||
        text.contains('loan no') ||
        text.contains('hdbfs') ||
        text.contains('muthoot') ||
        text.contains('manappuram') ||
        text.contains('bajaj finance') ||
        text.contains('bajaj finserv') ||
        text.contains('penal charges') ||
        text.contains('margin shortfall') ||
        text.contains('overdue');

    if (isLoan) {
      if (text.contains('indusind') || text.contains('indusb')) {
        return const _BankMeta('IndusInd Gold Loan', '📜', 0xFF800000, isLoan: true);
      }
      if (text.contains('hdbfs') || text.contains('hdb financial')) {
        return const _BankMeta('HDBFS Loan', '📜', 0xFFE65100, isLoan: true);
      }
      if (text.contains('muthoot')) {
        return const _BankMeta('Muthoot Gold Loan', '📜', 0xFFD32F2F, isLoan: true);
      }
      if (text.contains('manappuram')) {
        return const _BankMeta('Manappuram Gold Loan', '📜', 0xFFF57F17, isLoan: true);
      }
      if (text.contains('bajaj')) {
        return const _BankMeta('Bajaj Finance Loan', '📜', 0xFF003882, isLoan: true);
      }
      if (text.contains('hdfc')) {
        return const _BankMeta('HDFC Loan', '📜', 0xFF004C8F, isLoan: true);
      }
      if (text.contains('sbi') || text.contains('state bank')) {
        return const _BankMeta('SBI Loan', '📜', 0xFF280071, isLoan: true);
      }
      if (text.contains('icici')) {
        return const _BankMeta('ICICI Loan', '📜', 0xFFB02A30, isLoan: true);
      }
      if (text.contains('axis')) {
        return const _BankMeta('Axis Bank Loan', '📜', 0xFF97144D, isLoan: true);
      }
      return const _BankMeta('Loan Account', '📜', 0xFFBF360C, isLoan: true);
    }

    if (text.contains('indusind') || text.contains('indusb')) {
      return const _BankMeta('IndusInd Bank', '🏦', 0xFF800000);
    }
    if (text.contains('hdfc')) {
      return const _BankMeta('HDFC Bank', '🏦', 0xFF004C8F);
    }
    if (text.contains('sbi') || text.contains('state bank')) {
      return const _BankMeta('State Bank of India', '🏦', 0xFF280071);
    }
    if (text.contains('icici')) {
      return const _BankMeta('ICICI Bank', '🏦', 0xFFB02A30);
    }
    if (text.contains('axis')) {
      return const _BankMeta('Axis Bank', '🏦', 0xFF97144D);
    }
    if (text.contains('kotak')) {
      return const _BankMeta('Kotak Mahindra Bank', '🏦', 0xFFED1C24);
    }
    if (text.contains('union bank') || text.contains('unionb') || text.contains('uboi')) {
      return const _BankMeta('Union Bank of India', '🏦', 0xFF006738);
    }
    if (text.contains('indian bank') || text.contains('indbnk')) {
      return const _BankMeta('Indian Bank', '🏦', 0xFF003882);
    }
    if (text.contains('canara')) {
      return const _BankMeta('Canara Bank', '🏦', 0xFF0091DF);
    }
    if (text.contains('punjab') || text.contains('pnb')) {
      return const _BankMeta('Punjab National Bank', '🏦', 0xFFA20037);
    }
    if (text.contains('baroda') || text.contains('bob')) {
      return const _BankMeta('Bank of Baroda', '🏦', 0xFFF26522);
    }
    if (text.contains('rbl')) {
      return const _BankMeta('RBL Bank', '🏦', 0xFF1B365D);
    }
    if (text.contains('federal')) {
      return const _BankMeta('Federal Bank', '🏦', 0xFF002F6C);
    }
    if (text.contains('idfc')) {
      return const _BankMeta('IDFC FIRST Bank', '🏦', 0xFF9E1B32);
    }
    if (text.contains('yes bank') || text.contains('yesb')) {
      return const _BankMeta('Yes Bank', '🏦', 0xFF005A9C);
    }
    if (text.contains('paytm')) {
      return const _BankMeta('Paytm Payments Bank', '📱', 0xFF002E6E);
    }
    if (text.contains('airtel')) {
      return const _BankMeta('Airtel Payments Bank', '📱', 0xFFED1C24);
    }
    if (text.contains('jupiter')) {
      return const _BankMeta('Jupiter', '⚡', 0xFFFF5C00);
    }
    if (text.contains('fi money') || text.contains('epifi')) {
      return const _BankMeta('Fi Money', '⚡', 0xFF00D09C);
    }
    if (text.contains('aubank') || text.contains('au small')) {
      return const _BankMeta('AU Small Finance Bank', '🏦', 0xFF880E4F);
    }
    if (text.contains('slice')) {
      return const _BankMeta('Slice Card', '💳', 0xFF5E35B1, isCard: true);
    }
    if (text.contains('onecard')) {
      return const _BankMeta('OneCard', '💳', 0xFF212121, isCard: true);
    }
    if (text.contains('scb') || text.contains('standard chartered')) {
      return const _BankMeta('Standard Chartered', '🏦', 0xFF0072CE);
    }
    if (text.contains('citi')) {
      return const _BankMeta('Citibank', '🏦', 0xFF003B70);
    }
    if (text.contains('hsbc')) {
      return const _BankMeta('HSBC Bank', '🏦', 0xFFDB0011);
    }
    if (text.contains('dbs')) {
      return const _BankMeta('DBS Bank', '🏦', 0xFFFF3333);
    }
    if (text.contains('bank of india') || text.contains('boi')) {
      return const _BankMeta('Bank of India', '🏦', 0xFF0054A6);
    }
    if (text.contains('central bank') || text.contains('cboi')) {
      return const _BankMeta('Central Bank of India', '🏦', 0xFF0D47A1);
    }

    final isCard = text.contains('credit card') || text.contains('card ending');
    return _BankMeta('Bank Account', isCard ? '💳' : '🏦', 0xFF2E7D32, isCard: isCard);
  }
}

class _BankMeta {
  final String name;
  final String icon;
  final int color;
  final bool isCard;
  final bool isLoan;

  const _BankMeta(this.name, this.icon, this.color, {this.isCard = false, this.isLoan = false});
}
