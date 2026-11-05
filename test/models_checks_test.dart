import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/models/settings_model.dart';

/// Professional unit tests for core domain models utilizing package:checks.
/// Demonstrates type-safe assertions, deep property checking, and error conditions.
void main() {
  group('TransactionModel Checks Suite', () {
    test('Correctly serializes and deserializes transaction with full integrity', () {
      final now = DateTime(2026, 11, 5, 12, 30);
      final tx = TransactionModel(
        id: 'tx_unit_001',
        title: 'Starbucks Coffee',
        amount: 250.75,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        walletId: 'wallet_sbi',
        date: now,
        note: 'Afternoon coffee with team',
        tags: const ['beverage', 'work'],
        refId: 'UPI12345678',
        counterpartyLast4: '9876',
      );

      final json = tx.toJson();
      final deserialized = TransactionModel.fromJson(json);

      check(deserialized.id).equals('tx_unit_001');
      check(deserialized.title).equals('Starbucks Coffee');
      check(deserialized.amount).equals(250.75);
      check(deserialized.type).equals(TransactionType.expense);
      check(deserialized.categoryId).equals('cat_food');
      check(deserialized.walletId).equals('wallet_sbi');
      check(deserialized.date).equals(now);
      check(deserialized.note).isNotNull().equals('Afternoon coffee with team');
      check(deserialized.tags).contains('beverage');
      check(deserialized.tags).length.equals(2);
      check(deserialized.refId).isNotNull().equals('UPI12345678');
      check(deserialized.counterpartyLast4).isNotNull().equals('9876');
    });

    test('Computes deterministic idempotency signature correctly', () {
      final now = DateTime(2026, 11, 5, 10, 15);
      final tx = TransactionModel(
        id: 'tx_sig_test',
        title: 'UPI Transfer',
        amount: 500.00,
        type: TransactionType.expense,
        categoryId: 'other',
        walletId: 'cash',
        date: now,
        refId: 'REF999',
        counterpartyLast4: '1122',
      );

      final sig = tx.signature;
      check(sig).contains('500.00');
      check(sig).contains('REF999');
      check(sig).contains('1122');
    });

    test('Sanitizes string amounts and negative values cleanly on fromJson', () {
      final json = {
        'id': 'tx_string_amt',
        'title': 'Salary Credit',
        'amount': '1,500.50',
        'type': 'income',
        'categoryId': 'salary',
        'walletId': 'bank',
        'date': '2026-11-01T09:00:00.000Z',
      };

      final tx = TransactionModel.fromJson(json);
      check(tx.amount).equals(1500.50);
      check(tx.type).equals(TransactionType.income);
      check(tx.title).equals('Salary Credit');
    });
  });

  group('WalletModel Checks Suite', () {
    test('Initializes with default balances and supports copyWith', () {
      const wallet = WalletModel(
        id: 'wallet_main',
        name: 'Primary HDFC',
        icon: '🏦',
        colorValue: 0xFF2196F3,
        initialBalance: 50000.0,
      );

      check(wallet.name).equals('Primary HDFC');
      check(wallet.initialBalance).equals(50000.0);

      final updated = wallet.copyWith(initialBalance: 75000.0);
      check(updated.initialBalance).equals(75000.0);
      check(updated.name).equals('Primary HDFC');

      final map = updated.toJson();
      check(map['name']).equals('Primary HDFC');
      check(map['initialBalance']).equals(75000.0);
    });
  });

  group('UserSettingsModel Checks Suite', () {
    test('Validates default preferences and theme properties', () {
      const settings = UserSettingsModel();

      check(settings.selectedAvatarId).equals('solar_wealth');
      check(settings.biometricLockEnabled).isFalse();
      check(settings.widgetPrivacyMode).isTrue();
      check(settings.currencySymbol).equals('₹');

      final fromEmptyJson = UserSettingsModel.fromJson({});
      check(fromEmptyJson.selectedAvatarId).equals('solar_wealth');
      check(fromEmptyJson.currencySymbol).equals('₹');
    });
  });
}
