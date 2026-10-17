import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/pending_transaction_model.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/services/auto_import_service.dart';
import 'package:pocket/services/storage_service.dart';

class FakeStorageService extends Fake implements StorageService {
  @override
  List<WalletModel> getWallets() => [
        WalletModel(
          id: 'w_hdfc',
          name: 'HDFC Salary A/C',
          type: WalletType.bank,
          balance: 50000.0,
          accountNumber: '•••• 1234',
        ),
        WalletModel(
          id: 'w_ind',
          name: 'Indian Bank',
          type: WalletType.bank,
          balance: 15000.0,
          accountNumber: '•••• 0511',
        ),
        WalletModel(
          id: 'w_cash',
          name: 'Cash in Wallet',
          type: WalletType.cash,
          balance: 2000.0,
        ),
      ];

  @override
  List getCategories() => [];

  @override
  List getTransactions() => [];
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
  });
}
