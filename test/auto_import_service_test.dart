import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/pending_transaction_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/services/auto_import_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingTransactionModel Serialization Tests', () {
    test('Correctly deserializes from Map with diverse types', () {
      final now = DateTime(2026, 9, 14, 12, 0, 0);
      final json = {
        'id': 'txn_123',
        'amount': '1,499.50',
        'merchant': 'Swiggy',
        'appSource': 'Google Pay',
        'refId': 'UPI492019482910',
        'date': now.millisecondsSinceEpoch,
        'detectionSource': 'notification',
        'isIncome': false,
      };

      final model = PendingTransactionModel.fromJson(json);
      expect(model.id, 'txn_123');
      expect(model.amount, 1499.50);
      expect(model.merchant, 'Swiggy');
      expect(model.appSource, 'Google Pay');
      expect(model.refId, 'UPI492019482910');
      expect(model.date.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(model.detectionSource, 'notification');
      expect(model.isIncome, false);
    });

    test('Serializes to JSON and preserves fields', () {
      final now = DateTime(2026, 9, 14, 12, 0, 0);
      final model = PendingTransactionModel(
        id: 'txn_999',
        amount: 250.0,
        merchant: 'Uber Rides',
        appSource: 'PhonePe',
        refId: 'REF883921',
        date: now,
        detectionSource: 'screen_reader',
      );

      final json = model.toJson();
      expect(json['id'], 'txn_999');
      expect(json['amount'], 250.0);
      expect(json['merchant'], 'Uber Rides');
      expect(json['appSource'], 'PhonePe');
      expect(json['refId'], 'REF883921');
      expect(json['detectionSource'], 'screen_reader');
    });

    test('copyWith properly updates specific properties', () {
      final now = DateTime(2026, 9, 14, 12, 0, 0);
      final original = PendingTransactionModel(
        id: 'txn_1',
        amount: 100.0,
        merchant: 'Tea Stall',
        date: now,
      );

      final updated = original.copyWith(
        suggestedCategoryId: 'food',
        suggestedWalletId: 'wallet_upi',
      );

      expect(updated.id, 'txn_1');
      expect(updated.amount, 100.0);
      expect(updated.suggestedCategoryId, 'food');
      expect(updated.suggestedWalletId, 'wallet_upi');
    });
  });

  group('AutoImportService Deduplication & Heuristics Tests', () {
    late StorageService storage;
    late AutoImportService service;

    setUp(() async {
      storage = await StorageService.init();
      service = AutoImportService(storage);
    });

    test('Filters out non-positive amounts', () {
      final items = [
        PendingTransactionModel(
          id: '1',
          amount: 0.0,
          merchant: 'Zero',
          date: DateTime.now(),
        ),
        PendingTransactionModel(
          id: '2',
          amount: -50.0,
          merchant: 'Negative',
          date: DateTime.now(),
        ),
        PendingTransactionModel(
          id: '3',
          amount: 150.0,
          merchant: 'Valid',
          date: DateTime.now(),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(items);
      expect(result.length, 1);
      expect(result.first.merchant, 'Valid');
      expect(result.first.amount, 150.0);
    });

    test('Deduplicates multiple items in same batch by exact refId and merges metadata', () {
      final now = DateTime.now();
      final items = [
        PendingTransactionModel(
          id: 'notif_1',
          amount: 450.0,
          merchant: 'Swiggy Instamart',
          appSource: 'Google Pay',
          refId: '423984729384',
          date: now,
          detectionSource: 'notification',
        ),
        PendingTransactionModel(
          id: 'screen_1',
          amount: 450.0,
          merchant: 'Swiggy Instamart',
          appSource: 'Google Pay',
          refId: '423984729384',
          date: now.add(const Duration(seconds: 2)),
          detectionSource: 'screen_reader',
          rawPayload: 'Paid to Swiggy ₹450',
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(items);
      expect(result.length, 1);
      expect(result.first.amount, 450.0);
      expect(result.first.refId, '423984729384');
      expect(result.first.rawPayload, 'Paid to Swiggy ₹450');
    });

    test('Deduplicates multiple items in same batch by fuzzy merchant + amount + 60s window', () {
      final now = DateTime.now();
      final items = [
        PendingTransactionModel(
          id: 'screen_1',
          amount: 280.0,
          merchant: 'Uber India',
          date: now,
        ),
        PendingTransactionModel(
          id: 'notif_1',
          amount: 280.0,
          merchant: 'Uber India',
          date: now.add(const Duration(seconds: 25)),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(items);
      expect(result.length, 1);
      expect(result.first.amount, 280.0);
      expect(result.first.merchant, 'Uber India');
    });

    test('Does not deduplicate if amount differs or time window exceeds 60s', () {
      final now = DateTime.now();
      final items = [
        PendingTransactionModel(
          id: 'item_1',
          amount: 280.0,
          merchant: 'Uber India',
          date: now,
        ),
        PendingTransactionModel(
          id: 'item_2',
          amount: 280.0,
          merchant: 'Uber India',
          date: now.add(const Duration(seconds: 120)), // 2 minutes later
        ),
        PendingTransactionModel(
          id: 'item_3',
          amount: 350.0, // different amount
          merchant: 'Uber India',
          date: now.add(const Duration(seconds: 10)),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(items);
      expect(result.length, 3);
    });

    test('Discards item if already saved in database with matching refId', () async {
      final existingTx = TransactionModel(
        id: 'saved_1',
        title: 'Starbucks',
        amount: 320.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'default_cash',
        date: DateTime.now(),
        note: 'Ref: 987654321012',
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([existingTx]);

      final incoming = [
        PendingTransactionModel(
          id: 'incoming_1',
          amount: 320.0,
          merchant: 'Starbucks Coffee',
          refId: '987654321012',
          date: DateTime.now(),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(incoming);
      expect(result, isEmpty);
    });

    test('Discards item if already saved in database with fuzzy matching title + amount + 90s', () async {
      final now = DateTime.now();
      final existingTx = TransactionModel(
        id: 'saved_2',
        title: 'Zomato',
        amount: 540.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'default_cash',
        date: now,
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([existingTx]);

      final incoming = [
        PendingTransactionModel(
          id: 'incoming_2',
          amount: 540.0,
          merchant: 'Zomato',
          date: now.add(const Duration(seconds: 40)),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(incoming);
      expect(result, isEmpty);
    });

    test('Automatically assigns smart category and wallet heuristics', () async {
      final customWallet = WalletModel(
        id: 'wallet_upi_online',
        name: 'UPI / HDFC Bank',
        initialBalance: 10000.0,
        icon: '🏦',
        colorValue: 0xFF2196F3,
        walletType: WalletType.bank,
      );
      await storage.saveWallets([customWallet]);

      final incoming = [
        PendingTransactionModel(
          id: 'item_uber',
          amount: 190.0,
          merchant: 'Uber Auto Ride',
          appSource: 'Google Pay',
          date: DateTime.now(),
        ),
      ];

      final result = service.deduplicateAndAssignHeuristics(incoming);
      expect(result.length, 1);
      // Category heuristic should detect transport
      expect(result.first.suggestedCategoryId, isNotNull);
      // Wallet heuristic should detect UPI / Bank wallet over Cash
      expect(result.first.suggestedWalletId, contains('upi'));
    });

    test('Two-way enrichment: attaches screenshot image and richer merchant to existing SMS transaction', () {
      final existingSmsTx = TransactionModel(
        id: 'saved_sms_1',
        title: 'UPI Payment',
        amount: 350.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'wallet_hdfc',
        date: DateTime.now(),
        refId: '429812345678',
        note: 'Imported via SMS (AD-HDFC)',
        createdAt: DateTime.now(),
      );

      final incomingScreenshot = PendingTransactionModel(
        id: 'pending_screen_1',
        amount: 350.0,
        merchant: 'Swiggy',
        appSource: 'PhonePe',
        refId: '429812345678',
        imagePath: '/data/user/0/com.pocket.pocket/files/receipts/swiggy_receipt.jpg',
        date: DateTime.now(),
      );

      final enriched = service.enrichSavedTransaction(incomingScreenshot, [existingSmsTx], []);
      expect(enriched, isNotNull);
      expect(enriched!.id, 'saved_sms_1');
      expect(enriched.title, 'Swiggy');
      expect(enriched.receiptImagePath, '/data/user/0/com.pocket.pocket/files/receipts/swiggy_receipt.jpg');
      expect(enriched.walletId, 'wallet_hdfc'); // Preserves bank wallet
    });

    test('Two-way enrichment: updates bank wallet when SMS arrives for existing screenshot transaction', () {
      final hdfcWallet = WalletModel(
        id: 'wallet_hdfc_bank',
        name: 'HDFC Bank',
        initialBalance: 50000.0,
        icon: '🏦',
        colorValue: 0xFF003399,
        walletType: WalletType.bank,
        accountNumber: '1234',
      );

      final existingScreenshotTx = TransactionModel(
        id: 'saved_screen_1',
        title: 'Starbucks',
        amount: 450.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'default_cash',
        date: DateTime.now(),
        refId: '429898765432',
        receiptImagePath: '/data/user/0/com.pocket.pocket/files/receipts/starbucks.jpg',
        createdAt: DateTime.now(),
      );

      final incomingSms = PendingTransactionModel(
        id: 'pending_sms_1',
        amount: 450.0,
        merchant: 'Payment to Starbucks',
        appSource: 'SMS (HDFC)',
        refId: '429898765432',
        rawPayload: 'debited by 450 on HDFC Bank A/c ending 1234 to Starbucks',
        date: DateTime.now(),
      );

      final enriched = service.enrichSavedTransaction(incomingSms, [existingScreenshotTx], [hdfcWallet]);
      expect(enriched, isNotNull);
      expect(enriched!.id, 'saved_screen_1');
      expect(enriched.title, 'Starbucks'); // Preserves rich title
      expect(enriched.receiptImagePath, '/data/user/0/com.pocket.pocket/files/receipts/starbucks.jpg'); // Preserves receipt
      expect(enriched.walletId, 'wallet_hdfc_bank'); // Enriched to HDFC Bank from SMS!
    });
  });
}
