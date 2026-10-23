import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/budget_model.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/debt_model.dart';
import 'package:pocket/models/goal_model.dart';
import 'package:pocket/models/notification_model.dart';
import 'package:pocket/models/recurring_model.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/services/backup_service.dart';
import 'package:pocket/services/storage_service.dart';

class _MockStorageForBackup extends Fake implements StorageService {
  List<TransactionModel> txs = [];
  List<CategoryModel> cats = defaultCategories;
  List<WalletModel> wallets = defaultWallets;
  UserSettingsModel settings = const UserSettingsModel();
  List<RecurringRuleModel> recurring = [];
  List<AppNotificationModel> notifs = [];
  List<DebtModel> debts = [];
  List<CategoryBudgetModel> budgets = [];
  List<GoalModel> goals = [];

  @override
  List<TransactionModel> getTransactions() => txs;
  @override
  List<CategoryModel> getCategories() => cats;
  @override
  List<WalletModel> getWallets() => wallets;
  @override
  UserSettingsModel getSettings() => settings;
  @override
  List<RecurringRuleModel> getRecurringRules() => recurring;
  @override
  List<AppNotificationModel> getNotifications() => notifs;
  @override
  List<DebtModel> getDebts() => debts;
  @override
  List<CategoryBudgetModel> getCategoryBudgets() => budgets;
  @override
  List<GoalModel> getGoals() => goals;

  @override
  Future<void> saveTransactions(List<TransactionModel> list) async => txs = list;
  @override
  Future<void> saveCategories(List<CategoryModel> list) async => cats = list;
  @override
  Future<void> saveWallets(List<WalletModel> list) async => wallets = list;
  @override
  Future<void> saveSettings(UserSettingsModel s) async => settings = s;
  @override
  Future<void> saveRecurringRules(List<RecurringRuleModel> list) async => recurring = list;
  @override
  Future<void> saveNotifications(List<AppNotificationModel> list) async => notifs = list;
  @override
  Future<void> saveDebts(List<DebtModel> list) async => debts = list;
  @override
  Future<void> saveCategoryBudgets(List<CategoryBudgetModel> list) async => budgets = list;
  @override
  Future<void> saveGoals(List<GoalModel> list) async => goals = list;
}

void main() {
  group('Balance Sync & Wallet Edit Recalculation Tests', () {
    test('Recalculates initial balance correctly from edited current balance', () {
      const initialBalance = 1000.0;
      const currentBalance = 750.0;
      const netTransactions = currentBalance - initialBalance; // -250.0

      const newCurrentBalance = 900.0;
      final newInitialBalance = newCurrentBalance - netTransactions;

      expect(newInitialBalance, 1150.0);
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

  group('Deserialization Crash Immunization Tests', () {
    test('UserSettingsModel handles unknown enum strings without throwing', () {
      final malformedJson = {
        'userName': 'Alex',
        'themeMode': 'nonExistentTheme',
        'manualThemeStyle': 'ultraNeonDark',
        'themePreset': 'marsRed',
        'homeScreenWidgetStat': 'alienStat',
      };

      final settings = UserSettingsModel.fromJson(malformedJson);
      expect(settings.userName, 'Alex');
      expect(settings.themeMode, AppThemeMode.autoTime);
      expect(settings.manualThemeStyle, ManualThemeStyle.pureBlack);
      expect(settings.themePreset, AppThemePreset.emerald);
      expect(settings.homeScreenWidgetStat, HomeScreenWidgetStat.balanceAndTodaySpend);
    });

    test('TransactionModel handles unknown enums and string amounts without throwing', () {
      final json = {
        'id': 'tx_1',
        'title': 'Coffee',
        'amount': '150.50',
        'type': 'UNKNOWN_TYPE',
        'categoryId': 'food',
        'walletId': 'cash',
        'date': '2026-10-18T12:00:00Z',
      };

      final tx = TransactionModel.fromJson(json);
      expect(tx.id, 'tx_1');
      expect(tx.title, 'Coffee');
      expect(tx.amount, 150.50);
      expect(tx.type, TransactionType.expense);
    });

    test('CategoryModel handles unknown type safely', () {
      final json = {
        'id': 'c_custom',
        'name': 'Custom Cat',
        'icon': '⚡',
        'colorValue': 0xFF00FF00,
        'type': 'income_special',
      };

      final cat = CategoryModel.fromJson(json);
      expect(cat.type, TransactionType.income);
    });

    test('WalletModel handles unknown walletType without crashing', () {
      final json = {
        'id': 'w_crypto',
        'name': 'Crypto Wallet',
        'icon': '🪙',
        'colorValue': 0xFFFFD700,
        'walletType': 'crypto_layer2',
      };

      final wallet = WalletModel.fromJson(json);
      expect(wallet.walletType, WalletType.bank);
    });

    test('DebtModel handles unknown debt type gracefully', () {
      final json = {
        'id': 'd_1',
        'personName': 'John',
        'totalAmount': 500.0,
        'remainingAmount': 500.0,
        'type': 'invested',
        'createdAt': '2026-10-18T00:00:00Z',
      };

      final debt = DebtModel.fromJson(json);
      expect(debt.type, DebtType.lent);
    });

    test('RecurringRuleModel handles unknown frequencies safely', () {
      final json = {
        'id': 'r_1',
        'title': 'Server',
        'amount': 20.0,
        'type': 'expense',
        'frequency': 'biweekly_leap',
        'templatePreset': 'unrecognized_preset',
        'nextDueDate': '2026-11-01T00:00:00Z',
      };

      final rule = RecurringRuleModel.fromJson(json);
      expect(rule.frequency, RecurringFrequency.monthly);
      expect(rule.templatePreset, RecurringTemplatePreset.custom);
    });

    test('AppNotificationModel handles unknown notification types safely', () {
      final json = {
        'id': 'n_1',
        'title': 'Alert',
        'message': 'Warning',
        'type': 'satellite_push',
        'createdAt': '2026-10-18T00:00:00Z',
      };

      final notif = AppNotificationModel.fromJson(json);
      expect(notif.type, NotificationType.system);
    });
  });

  group('Backup Parity & Running Balance Precision Tests', () {
    test('BackupService includes goals in JSON export and restores them accurately', () async {
      final storage = _MockStorageForBackup();
      final goal = GoalModel(
        id: 'g_car',
        title: 'New Car',
        targetAmount: 500000.0,
        currentSavedAmount: 75000.0,
        createdAt: DateTime(2026, 1, 1),
      );
      storage.goals = [goal];

      final backupService = BackupService(storage);
      final jsonStr = backupService.exportJsonBackupString();

      expect(jsonStr.contains('g_car'), isTrue);
      expect(jsonStr.contains('New Car'), isTrue);
      expect(jsonStr.contains('500000'), isTrue);

      // Clear storage goals and restore
      storage.goals = [];
      final restored = await backupService.restoreFromJsonString(jsonStr);
      expect(restored, isTrue);
      expect(storage.goals.length, 1);
      expect(storage.goals.first.id, 'g_car');
      expect(storage.goals.first.title, 'New Car');
      expect(storage.goals.first.targetAmount, 500000.0);
      expect(storage.goals.first.currentSavedAmount, 75000.0);
    });

    test('Running balance calculation eliminates floating point drift and negative zero', () {
      final initialBalance = 100.0;
      final amounts = [33.33, 33.33, 33.34];

      double balance = initialBalance;
      for (final a in amounts) {
        balance -= a;
        balance = (balance * 100).round() / 100.0;
        if (balance.abs() < 0.0001) balance = 0.0;
      }

      expect(balance, 0.0);
      expect(balance.isNegative, isFalse);
    });
  });

  group('Onboarding & SMS Balance Snapshot Calibration Tests', () {
    test('WalletModel correctly serializes and restores balanceSnapshotAt', () {
      final snapshotDate = DateTime.parse('2026-10-23T14:30:00.000Z');
      final wallet = WalletModel(
        id: 'w_test',
        name: 'IndusInd Bank',
        initialBalance: 9500.0,
        currentBalance: 9500.0,
        balanceSnapshotAt: snapshotDate,
      );

      final json = wallet.toJson();
      expect(json['balanceSnapshotAt'], '2026-10-23T14:30:00.000Z');

      final restored = WalletModel.fromJson(json);
      expect(restored.balanceSnapshotAt, snapshotDate);
      expect(restored.initialBalance, 9500.0);
    });

    test('Transactions dated before or at balanceSnapshotAt do not double-deduct from balance', () {
      final snapshotDate = DateTime.parse('2026-10-23T14:30:00.000Z');
      final wallet = WalletModel(
        id: 'w_test',
        name: 'IndusInd Bank',
        initialBalance: 9500.0,
        currentBalance: 9500.0,
        balanceSnapshotAt: snapshotDate,
      );

      final oldTx1 = TransactionModel(
        id: 'tx_old_1',
        title: 'Yesterday Lunch',
        amount: 250.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_test',
        date: snapshotDate.subtract(const Duration(hours: 5)),
      );

      final snapshotTx = TransactionModel(
        id: 'tx_snapshot',
        title: 'Swiggy Order',
        amount: 500.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_test',
        date: snapshotDate, // exact moment Avl Bal: 9500 was generated
      );

      final newTx = TransactionModel(
        id: 'tx_new',
        title: 'Tea & Snacks',
        amount: 40.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'w_test',
        date: snapshotDate.add(const Duration(minutes: 30)),
      );

      final allTxs = [oldTx1, snapshotTx, newTx];

      // Simulate reactive balance calculation
      double calculatedBalance = wallet.initialBalance;
      for (final tx in allTxs) {
        if (wallet.balanceSnapshotAt != null && !tx.date.isAfter(wallet.balanceSnapshotAt!)) {
          continue; // Prior transactions were already baked into the bank's snapshot
        }
        if (tx.type == TransactionType.income) {
          calculatedBalance += tx.amount;
        } else {
          calculatedBalance -= tx.amount;
        }
      }

      // 9500 - 40 = 9460. The 250 and 500 debits do NOT double-deduct!
      expect(calculatedBalance, 9460.0);
    });
  });
}
