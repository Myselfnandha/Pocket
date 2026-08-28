import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/recurring_model.dart';
import '../models/notification_model.dart';
import '../models/debt_model.dart';
import '../models/budget_model.dart';
import 'storage_service.dart';

class BackupService {
  final StorageService _storage;

  BackupService(this._storage);

  // --- Export Full JSON Backup ---

  String exportJsonBackupString() {
    final transactions = _storage.getTransactions();
    final categories = _storage.getCategories();
    final wallets = _storage.getWallets();
    final settings = _storage.getSettings();
    final recurring = _storage.getRecurringRules();
    final notifications = _storage.getNotifications();
    final debts = _storage.getDebts();
    final budgets = _storage.getCategoryBudgets();

    final Map<String, dynamic> backupData = {
      'schemaVersion': 2,
      'appName': 'Pocket',
      'exportTimestamp': DateTime.now().toIso8601String(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'wallets': wallets.map((e) => e.toJson()).toList(),
      'settings': settings.toJson(),
      'recurringRules': recurring.map((e) => e.toJson()).toList(),
      'notifications': notifications.map((e) => e.toJson()).toList(),
      'debts': debts.map((e) => e.toJson()).toList(),
      'categoryBudgets': budgets.map((e) => e.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  Future<File> exportJsonBackup() async {
    final jsonStr = exportJsonBackupString();
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Pocket_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonStr);

    return file;
  }

  Future<void> shareBackupFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Pocket Complete Financial Backup',
    );
  }

  // --- Restore Full JSON Backup ---

  Future<bool> restoreFromJsonString(String jsonContent) async {
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonContent);

      if (!decoded.containsKey('transactions') || !decoded.containsKey('wallets')) {
        return false;
      }

      // Parse transactions
      final List<dynamic> rawTxs = decoded['transactions'] as List<dynamic>? ?? [];
      final List<TransactionModel> txs =
          rawTxs.map((e) => TransactionModel.fromJson(e as Map<String, dynamic>)).toList();

      // Parse categories
      final List<dynamic> rawCats = decoded['categories'] as List<dynamic>? ?? [];
      final List<CategoryModel> cats = rawCats.isNotEmpty
          ? rawCats.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList()
          : defaultCategories;

      // Parse wallets
      final List<dynamic> rawWallets = decoded['wallets'] as List<dynamic>? ?? [];
      final List<WalletModel> wallets = rawWallets.isNotEmpty
          ? rawWallets.map((e) => WalletModel.fromJson(e as Map<String, dynamic>)).toList()
          : defaultWallets;

      // Parse settings
      final Map<String, dynamic>? rawSettings = decoded['settings'] as Map<String, dynamic>?;
      final UserSettingsModel settings =
          rawSettings != null ? UserSettingsModel.fromJson(rawSettings) : const UserSettingsModel();

      // Parse recurring rules
      final List<dynamic> rawRecurring = decoded['recurringRules'] as List<dynamic>? ?? [];
      final List<RecurringRuleModel> recurring = rawRecurring
          .map((e) => RecurringRuleModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Parse notifications
      final List<dynamic> rawNotifs = decoded['notifications'] as List<dynamic>? ?? [];
      final List<AppNotificationModel> notifs = rawNotifs
          .map((e) => AppNotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Parse debts
      final List<dynamic> rawDebts = decoded['debts'] as List<dynamic>? ?? [];
      final List<DebtModel> debts = rawDebts
          .map((e) => DebtModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Parse budgets
      final List<dynamic> rawBudgets = decoded['categoryBudgets'] as List<dynamic>? ?? [];
      final List<CategoryBudgetModel> budgets = rawBudgets
          .map((e) => CategoryBudgetModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Save to storage
      await _storage.saveTransactions(txs);
      await _storage.saveCategories(cats);
      await _storage.saveWallets(wallets);
      await _storage.saveSettings(settings);
      await _storage.saveRecurringRules(recurring);
      await _storage.saveNotifications(notifs);
      await _storage.saveDebts(debts);
      await _storage.saveCategoryBudgets(budgets);

      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Import CSV Transactions ---

  Future<int> importFromCsvString(String csvContent) async {
    try {
      final List<List<dynamic>> rows =
          const CsvToListConverter(eol: '\n').convert(csvContent);
      if (rows.length < 2) return 0;

      final categories = _storage.getCategories();
      final wallets = _storage.getWallets();
      final existingTxs = _storage.getTransactions();

      int importedCount = 0;
      final List<TransactionModel> newTxs = [];

      // Assume header at index 0, iterate data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 5) continue;

        try {
          final title = row[2].toString().trim();
          if (title.isEmpty) continue;

          final typeStr = row[3].toString().trim().toLowerCase();
          final type = typeStr.contains('income')
              ? TransactionType.income
              : TransactionType.expense;

          final amount = double.tryParse(row[4].toString().replaceAll(',', '').trim()) ?? 0.0;
          if (amount <= 0) continue;

          DateTime date = DateTime.now();
          try {
            date = DateTime.parse(row[1].toString().trim());
          } catch (_) {
            date = DateTime.now();
          }

          final catName = (row.length > 5 ? row[5].toString().trim() : 'Other');
          final cat = categories.firstWhere(
            (c) => c.name.toLowerCase() == catName.toLowerCase(),
            orElse: () => categories.first,
          );

          final walletName = (row.length > 6 ? row[6].toString().trim() : 'cash');
          final wallet = wallets.firstWhere(
            (w) => w.id == walletName || w.name.toLowerCase() == walletName.toLowerCase(),
            orElse: () => wallets.first,
          );

          final note = row.length > 7 ? row[7].toString().trim() : null;

          newTxs.add(
            TransactionModel(
              id: const Uuid().v4(),
              title: title,
              amount: amount,
              type: type,
              categoryId: cat.id,
              walletId: wallet.id,
              date: date,
              note: note,
              createdAt: DateTime.now(),
            ),
          );
          importedCount++;
        } catch (_) {}
      }

      if (importedCount > 0) {
        await _storage.saveTransactions([...newTxs, ...existingTxs]);
      }

      return importedCount;
    } catch (_) {
      return 0;
    }
  }
}
