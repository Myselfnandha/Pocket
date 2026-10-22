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
    required this.transactionCount,
  });

  String get maskedAccountNumber => '•••• $accountLast4';

  WalletModel toWallet({required String currencySymbol, bool isDefault = false}) {
    return WalletModel(
      id: id,
      name: bankName,
      type: type,
      currencySymbol: currencySymbol,
      initialBalance: currentBalance,
      currentBalance: currentBalance,
      icon: icon,
      colorValue: colorValue,
      accountNumber: accountLast4,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );
  }
}

class BankDiscoveryService {
  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|ac|account|card|acct)\s*(?:no\.?|num\.?)?\s*(?:ending(?:\s+in|\s+with)?)?\s*[*xX.-]*([0-9]{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _availBalPattern = RegExp(
    r'(?:avl\s*bal|available\s*balance|net\s*bal|tot\s*bal|clear\s*bal|bal|balance)\b[:\s]*(?:(?:is|in your a/c is|in a/c is)\s+)?(?:(?:rs\.?|rs:|inr|₹|usd|\$)[:\s]*)?([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Scans device SMS inbox and aggregates unique bank accounts & cards with real available balances
  static Future<List<DiscoveredBankAccount>> discoverFromSms(
    AutoImportService autoImportService, {
    int daysLookback = 0,
  }) async {
    final smsList = await autoImportService.scanSmsInbox(daysLookback: daysLookback);
    if (smsList.isEmpty) return [];

    // Map key: "bankName_last4" -> DiscoveredBankAccount
    final Map<String, DiscoveredBankAccount> discoveredMap = {};
    final Map<String, int> txCounts = {};

    for (final item in smsList) {
      final payload = item.rawPayload ?? '';
      final appSource = item.appSource;
      final fullTextLower = '$appSource $payload'.toLowerCase();

      // Skip loan or overdue collection accounts from primary wallet discovery
      final isLoan = fullTextLower.contains('gold loan') ||
          fullTextLower.contains('loan a/c') ||
          fullTextLower.contains('loan account') ||
          fullTextLower.contains('penal charges') ||
          fullTextLower.contains('margin shortfall');
      if (isLoan) {
        continue;
      }

      // 1. Extract account last 4
      String? last4 = item.counterpartyLast4;
      if (last4 == null || last4.isEmpty) {
        final match = _accountPattern.firstMatch(payload);
        if (match != null) {
          last4 = match.group(1);
        }
      }

      if (last4 == null || last4.trim().isEmpty) {
        continue;
      }
      last4 = last4.trim();

      // 2. Resolve Bank Info
      final bankInfo = _resolveBankInfo(appSource, payload);
      final key = '${bankInfo.name}_$last4';

      txCounts[key] = (txCounts[key] ?? 0) + 1;

      // Extract available balance if present in the message
      double? extractedBal;
      final balMatch = _availBalPattern.firstMatch(payload);
      if (balMatch != null) {
        final rawNum = balMatch.group(1)?.replaceAll(',', '').trim();
        if (rawNum != null) {
          extractedBal = double.tryParse(rawNum);
        }
      }

      if (!discoveredMap.containsKey(key)) {
        discoveredMap[key] = DiscoveredBankAccount(
          id: 'discovered_${DateTime.now().microsecondsSinceEpoch}_$last4',
          bankName: bankInfo.name,
          accountLast4: last4,
          currentBalance: extractedBal ?? 0.0,
          hasBalance: extractedBal != null,
          icon: bankInfo.icon,
          colorValue: bankInfo.color,
          type: bankInfo.isCard ? WalletType.creditCard : WalletType.bank,
          latestDate: item.date,
          transactionCount: 1,
        );
      } else {
        final existing = discoveredMap[key]!;
        // If newer message didn't have balance reported, but this older message does, adopt it
        final hasBal = existing.hasBalance || extractedBal != null;
        final bestBal = existing.hasBalance ? existing.currentBalance : (extractedBal ?? 0.0);
        discoveredMap[key] = DiscoveredBankAccount(
          id: existing.id,
          bankName: existing.bankName,
          accountLast4: existing.accountLast4,
          currentBalance: bestBal,
          hasBalance: hasBal,
          icon: existing.icon,
          colorValue: existing.colorValue,
          type: existing.type,
          latestDate: existing.latestDate,
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

    if (text.contains('indusind') || text.contains('indusb')) {
      return _BankMeta('IndusInd Bank', '🏦', 0xFF800000);
    }
    if (text.contains('hdfc')) {
      return _BankMeta('HDFC Bank', '🏦', 0xFF004C8F);
    }
    if (text.contains('sbi') || text.contains('state bank')) {
      return _BankMeta('State Bank of India', '🏦', 0xFF280071);
    }
    if (text.contains('icici')) {
      return _BankMeta('ICICI Bank', '🏦', 0xFFB02A30);
    }
    if (text.contains('axis')) {
      return _BankMeta('Axis Bank', '🏦', 0xFF97144D);
    }
    if (text.contains('kotak')) {
      return _BankMeta('Kotak Mahindra Bank', '🏦', 0xFFED1C24);
    }
    if (text.contains('union bank') || text.contains('unionb') || text.contains('uboi')) {
      return _BankMeta('Union Bank of India', '🏦', 0xFF006738);
    }
    if (text.contains('indian bank') || text.contains('indbnk')) {
      return _BankMeta('Indian Bank', '🏦', 0xFF003882);
    }
    if (text.contains('canara')) {
      return _BankMeta('Canara Bank', '🏦', 0xFF0091DF);
    }
    if (text.contains('punjab') || text.contains('pnb')) {
      return _BankMeta('Punjab National Bank', '🏦', 0xFFA20037);
    }
    if (text.contains('baroda') || text.contains('bob')) {
      return _BankMeta('Bank of Baroda', '🏦', 0xFFF26522);
    }
    if (text.contains('rbl')) {
      return _BankMeta('RBL Bank', '🏦', 0xFF1B365D);
    }
    if (text.contains('federal')) {
      return _BankMeta('Federal Bank', '🏦', 0xFF002F6C);
    }
    if (text.contains('idfc')) {
      return _BankMeta('IDFC FIRST Bank', '🏦', 0xFF9E1B32);
    }
    if (text.contains('yes bank') || text.contains('yesb')) {
      return _BankMeta('Yes Bank', '🏦', 0xFF005A9C);
    }
    if (text.contains('paytm')) {
      return _BankMeta('Paytm Payments Bank', '📱', 0xFF002E6E);
    }
    if (text.contains('airtel')) {
      return _BankMeta('Airtel Payments Bank', '📱', 0xFFED1C24);
    }
    if (text.contains('jupiter')) {
      return _BankMeta('Jupiter', '⚡', 0xFFFF5C00);
    }
    if (text.contains('fi money') || text.contains('epifi')) {
      return _BankMeta('Fi Money', '⚡', 0xFF00D09C);
    }
    if (text.contains('aubank') || text.contains('au small')) {
      return _BankMeta('AU Small Finance Bank', '🏦', 0xFF880E4F);
    }
    if (text.contains('slice')) {
      return _BankMeta('Slice Card', '💳', 0xFF5E35B1, isCard: true);
    }
    if (text.contains('onecard')) {
      return _BankMeta('OneCard', '💳', 0xFF212121, isCard: true);
    }
    if (text.contains('scb') || text.contains('standard chartered')) {
      return _BankMeta('Standard Chartered', '🏦', 0xFF0072CE);
    }
    if (text.contains('citi')) {
      return _BankMeta('Citibank', '🏦', 0xFF003B70);
    }
    if (text.contains('hsbc')) {
      return _BankMeta('HSBC Bank', '🏦', 0xFFDB0011);
    }
    if (text.contains('dbs')) {
      return _BankMeta('DBS Bank', '🏦', 0xFFFF3333);
    }
    if (text.contains('bank of india') || text.contains('boi')) {
      return _BankMeta('Bank of India', '🏦', 0xFF0054A6);
    }
    if (text.contains('central bank') || text.contains('cboi')) {
      return _BankMeta('Central Bank of India', '🏦', 0xFF0D47A1);
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

  const _BankMeta(this.name, this.icon, this.color, {this.isCard = false});
}
