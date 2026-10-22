import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/pending_transaction_model.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/services/auto_import_service.dart';
import 'package:pocket/services/storage_service.dart';

class FakeStorageService extends Fake implements StorageService {
  @override
  List<WalletModel> getWallets() => [
        WalletModel(
          id: 'w_hdfc',
          name: 'HDFC Salary A/C',
          icon: 'account_balance',
          colorValue: 0xFF2196F3,
          walletType: WalletType.bank,
          currentBalance: 50000.0,
          accountNumber: '•••• 1234',
        ),
        WalletModel(
          id: 'w_ind',
          name: 'Indian Bank',
          icon: 'account_balance',
          colorValue: 0xFF4CAF50,
          walletType: WalletType.bank,
          currentBalance: 15000.0,
          accountNumber: '•••• 0511',
        ),
        WalletModel(
          id: 'w_cash',
          name: 'Cash in Wallet',
          icon: 'payments',
          colorValue: 0xFFFF9800,
          walletType: WalletType.cash,
          currentBalance: 2000.0,
        ),
      ];

  @override
  List<CategoryModel> getCategories() => [];

  @override
  List<TransactionModel> getTransactions() => [];
}

void main() {
  group('SMS Auto-Read & Auto-Log Tests', () {
    test('UserSettingsModel serializes autoSaveSms and autoReadSmsEnabled', () {
      const defaultSettings = UserSettingsModel();
      expect(defaultSettings.autoSaveSms, isFalse);
      expect(defaultSettings.autoReadSmsEnabled, isTrue);

      final updated = defaultSettings.copyWith(
        autoSaveSms: true,
        autoReadSmsEnabled: false,
      );
      expect(updated.autoSaveSms, isTrue);
      expect(updated.autoReadSmsEnabled, isFalse);

      final json = updated.toJson();
      expect(json['autoSaveSms'], isTrue);
      expect(json['autoReadSmsEnabled'], isFalse);

      final reconstructed = UserSettingsModel.fromJson(json);
      expect(reconstructed.autoSaveSms, isTrue);
      expect(reconstructed.autoReadSmsEnabled, isFalse);
    });

    test('AutoImportService accurately matches wallet via counterpartyLast4', () {
      final storage = FakeStorageService();
      final service = AutoImportService(storage);

      final itemWithIndBank = PendingTransactionModel(
        id: 'sms_1',
        amount: 450.0,
        merchant: 'Swiggy',
        appSource: 'SMS (VK-INDBNK)',
        date: DateTime.now(),
        detectionSource: 'sms',
        counterpartyLast4: '0511',
      );

      final processed = service.deduplicateAndAssignHeuristics([itemWithIndBank]);
      expect(processed.length, 1);
      expect(processed.first.suggestedWalletId, 'w_ind');

      final itemWithHdfc = PendingTransactionModel(
        id: 'sms_2',
        amount: 1200.0,
        merchant: 'Amazon',
        appSource: 'SMS (AD-HDFCBK)',
        date: DateTime.now(),
        detectionSource: 'sms',
        counterpartyLast4: '1234',
      );

      final processedHdfc = service.deduplicateAndAssignHeuristics([itemWithHdfc]);
      expect(processedHdfc.length, 1);
      expect(processedHdfc.first.suggestedWalletId, 'w_hdfc');
    });

    test('AutoImportService deduplicates identical SMS items with matching refId', () {
      final storage = FakeStorageService();
      final service = AutoImportService(storage);

      final item1 = PendingTransactionModel(
        id: 'sms_dup_1',
        amount: 250.0,
        merchant: 'Zomato',
        appSource: 'SMS (VK-INDBNK)',
        refId: '428901234567',
        date: DateTime(2026, 10, 17, 14, 30),
        detectionSource: 'sms',
      );

      final item2 = PendingTransactionModel(
        id: 'sms_dup_2',
        amount: 250.0,
        merchant: 'Zomato Food',
        appSource: 'SMS (VK-INDBNK)',
        refId: '428901234567',
        date: DateTime(2026, 10, 17, 14, 30),
        detectionSource: 'sms',
      );

      final processed = service.deduplicateAndAssignHeuristics([item1, item2]);
      expect(processed.length, 1);
      expect(processed.first.refId, '428901234567');
    });

    test('TransactionModel serializes and deserializes appSource, rawPayload, and counterpartyLast4', () {
      final tx = TransactionModel(
        id: 'tx_meta_1',
        title: 'Salary Credit',
        amount: 85000.0,
        type: TransactionType.income,
        categoryId: 'salary',
        walletId: 'w_hdfc',
        date: DateTime(2026, 10, 15, 10, 0),
        counterpartyLast4: '1234',
        appSource: 'SMS (AD-HDFCBK)',
        rawPayload: 'Your A/C 1234 is credited with Rs 85,000 on 15-OCT-26 by Salary',
        createdAt: DateTime(2026, 10, 15, 10, 1),
      );

      final json = tx.toJson();
      expect(json['counterpartyLast4'], '1234');
      expect(json['appSource'], 'SMS (AD-HDFCBK)');
      expect(json['rawPayload'], contains('Salary'));

      final reconstructed = TransactionModel.fromJson(json);
      expect(reconstructed.counterpartyLast4, '1234');
      expect(reconstructed.appSource, 'SMS (AD-HDFCBK)');
      expect(reconstructed.rawPayload, tx.rawPayload);
    });

    test('AutoImportService assigns income category rather than expense category for credits', () {
      final storage = FakeStorageService();
      final service = AutoImportService(storage);

      final salaryItem = PendingTransactionModel(
        id: 'sms_sal_1',
        amount: 75000.0,
        merchant: 'Infosys Payroll',
        appSource: 'SMS (VK-INDBNK)',
        date: DateTime.now(),
        detectionSource: 'sms',
        isIncome: true,
        rawPayload: 'A/c 0511 credited with INR 75,000 for monthly salary payroll',
      );

      final processed = service.deduplicateAndAssignHeuristics([salaryItem]);
      expect(processed.length, 1);
      expect(processed.first.suggestedCategoryId, 'salary');
    });

    test('AutoImportService.isAlreadySaved correctly identifies duplicates in saved transactions', () {
      final storage = FakeStorageService();
      final service = AutoImportService(storage);

      final savedTxs = [
        TransactionModel(
          id: 'existing_1',
          title: 'Swiggy',
          amount: 340.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'w_ind',
          refId: 'UTR99887766',
          date: DateTime(2026, 10, 17, 12, 0),
          createdAt: DateTime(2026, 10, 17, 12, 1),
        ),
      ];

      final matchingItem = PendingTransactionModel(
        id: 'new_item_1',
        amount: 340.0,
        merchant: 'Swiggy Food',
        refId: 'UTR99887766',
        date: DateTime(2026, 10, 17, 12, 0),
      );

      expect(service.isAlreadySaved(matchingItem, savedTxs), isTrue);

      final differentItem = PendingTransactionModel(
        id: 'new_item_2',
        amount: 550.0,
        merchant: 'Amazon',
        refId: 'UTR11223344',
        date: DateTime(2026, 10, 17, 12, 0),
      );

      expect(service.isAlreadySaved(differentItem, savedTxs), isFalse);
    });

    test('Floating-point rounding prevents IEEE 754 precision drift and negative zero', () {
      double rawBalance = 0.1 + 0.2 - 0.3; // Typically 5.551115123125783e-17
      double rounded = (rawBalance * 100).round() / 100.0;
      if (rounded.abs() < 0.0001) rounded = 0.0;
      expect(rounded, 0.0);
      expect(rounded.isNegative, isFalse);

      double sum = 19.99 + 10.01;
      double sumRounded = (sum * 100).round() / 100.0;
      expect(sumRounded, 30.0);
    });

    test('Inter-wallet transfers with categoryId cat_transfer do not count as external expense', () {
      final transferExpense = TransactionModel(
        id: 'tx_trf_1',
        title: 'Transfer to Cash',
        amount: 5000.0,
        type: TransactionType.expense,
        categoryId: 'cat_transfer',
        walletId: 'w_hdfc',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final transferIncome = TransactionModel(
        id: 'tx_trf_2',
        title: 'Transfer from HDFC',
        amount: 5000.0,
        type: TransactionType.income,
        categoryId: 'cat_transfer',
        walletId: 'w_cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final actualExpense = TransactionModel(
        id: 'tx_exp_1',
        title: 'Groceries',
        amount: 1200.0,
        type: TransactionType.expense,
        categoryId: 'groceries',
        walletId: 'w_hdfc',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final txs = [transferExpense, transferIncome, actualExpense];

      double externalExpense = 0.0;
      for (final tx in txs) {
        if (tx.categoryId == 'cat_transfer') continue;
        if (tx.type == TransactionType.expense) {
          externalExpense += tx.amount;
        }
      }

      expect(externalExpense, 1200.0);
    });
  });
}
