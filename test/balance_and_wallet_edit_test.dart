import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/wallet_model.dart';

void main() {
  group('Balance Sync & Wallet Edit Recalculation Tests', () {
    test('Recalculates initial balance correctly from edited current balance', () {
      // Suppose an account started with initial balance = 1000.0
      // Net transactions (income - expense) = -250.0 (user spent 250)
      // Current calculated balance = 750.0
      const initialBalance = 1000.0;
      const currentBalance = 750.0;
      const netTransactions = currentBalance - initialBalance; // -250.0

      // User enters new current balance = 900.0
      const newCurrentBalance = 900.0;
      final newInitialBalance = newCurrentBalance - netTransactions;

      expect(newInitialBalance, 1150.0);

      // Now verify that applying netTransactions to newInitialBalance yields exactly newCurrentBalance
      final verifiedCurrentBalance = newInitialBalance + netTransactions;
      expect(verifiedCurrentBalance, newCurrentBalance);
    });

    test('WalletModel copyWith updates fields properly', () {
      final wallet = WalletModel(
        id: 'w1',
        name: 'HDFC Bank',
        initialBalance: 5000.0,
        currentBalance: 4500.0,
        walletType: WalletType.bank,
        icon: '🏦',
        colorValue: 0xFF2196F3,
        isDefault: true,
      );

      final updated = wallet.copyWith(
        name: 'HDFC Salary',
        initialBalance: 6000.0,
        currentBalance: 5500.0,
      );

      expect(updated.name, 'HDFC Salary');
      expect(updated.initialBalance, 6000.0);
      expect(updated.currentBalance, 5500.0);
      expect(updated.icon, '🏦');
      expect(updated.isDefault, true);
    });

    test('UserSettingsModel serializes and deserializes new configuration properties', () {
      final settings = UserSettingsModel(
        customAvatarPath: '/data/user/0/com.pocket.pocket/app_flutter/avatar.png',
        defaultWalletId: 'w_test_123',
        autoSaveScreenshots: true,
        duplicateDetectionWindowSeconds: 1800,
        monthStartDay: 5,
        biometricLockEnabled: true,
        hapticFeedbackEnabled: false,
        defaultQuickAddType: 'income',
      );

      final json = settings.toJson();
      expect(json['customAvatarPath'], '/data/user/0/com.pocket.pocket/app_flutter/avatar.png');
      expect(json['defaultWalletId'], 'w_test_123');
      expect(json['autoSaveScreenshots'], true);
      expect(json['duplicateDetectionWindowSeconds'], 1800);
      expect(json['monthStartDay'], 5);
      expect(json['biometricLockEnabled'], true);
      expect(json['hapticFeedbackEnabled'], false);
      expect(json['defaultQuickAddType'], 'income');

      final deserialized = UserSettingsModel.fromJson(json);
      expect(deserialized.customAvatarPath, settings.customAvatarPath);
      expect(deserialized.defaultWalletId, settings.defaultWalletId);
      expect(deserialized.autoSaveScreenshots, true);
      expect(deserialized.duplicateDetectionWindowSeconds, 1800);
      expect(deserialized.monthStartDay, 5);
      expect(deserialized.biometricLockEnabled, true);
      expect(deserialized.hapticFeedbackEnabled, false);
      expect(deserialized.defaultQuickAddType, 'income');
    });
  });
}
