import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final wallets = ref.watch(walletsProvider);
    final categories = ref.watch(categoriesProvider);
    final recurring = ref.watch(recurringRulesProvider);
    final backupService = ref.watch(backupServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Local Database Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storage_rounded, color: AppColors.primaryGreenLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local Encrypted Database',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All data is stored locally on this device',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Transactions', '${transactions.length}', isDark),
                    _buildMetric('Wallets', '${wallets.length}', isDark),
                    _buildMetric('Categories', '${categories.length}', isDark),
                    _buildMetric('Recurring', '${recurring.length}', isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Section: Backup & Restore
          _buildSectionHeader('BACKUP & RESTORE'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryGreenLight),
                  title: const Text('Export JSON Database Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export all transactions, wallets, rules, and settings to a JSON file'),
                  trailing: const Icon(Icons.share_outlined, size: 20),
                  onTap: () async {
                    try {
                      final file = await backupService.exportJsonBackup();
                      await backupService.shareBackupFile(file);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup exported successfully ✓'), duration: Duration(seconds: 4)),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to export backup: $e'), duration: const Duration(seconds: 4)),
                      );
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, color: AppColors.infoBlue),
                  title: const Text('Restore Database from Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Restore complete state from a previously saved Pocket JSON backup'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _confirmRestore(context, ref, backupService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Section: Data Import & Export
          _buildSectionHeader('IMPORT & EXPORT'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: AppColors.accentOrange),
                  title: const Text('Import CSV Transactions', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Import transactions from a spreadsheet CSV file'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickAndImportCsv(context, ref, backupService),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: AppColors.primaryGreenLight),
                  title: const Text('Export All to CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Export all ${transactions.length} transactions as spreadsheet'),
                  trailing: const Icon(Icons.share_outlined, size: 20),
                  onTap: () => _exportAllCsv(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Section: Danger Zone
          _buildSectionHeader('DANGER ZONE'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.expenseRed.withValues(alpha: 0.3),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expenseRed),
              title: const Text('Reset All Data', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenseRed)),
              subtitle: const Text('Erase all transactions, wallets, and reset app to initial state'),
              onTap: () => _confirmResetAllData(context, ref),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.primaryGreenLight,
        ),
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref, dynamic backupService) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text('This will overwrite all existing local transactions, wallets, and settings with the backup file data. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.infoBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final success = await backupService.restoreFromJsonString(content);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                ref.invalidate(transactionsProvider);
                ref.invalidate(walletsProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(settingsProvider);
                ref.invalidate(recurringRulesProvider);
                ref.invalidate(notificationsProvider);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database restored successfully ✓'), duration: Duration(seconds: 4)),
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to restore. Invalid backup file structure.'), duration: Duration(seconds: 4)),
                );
              }
            },
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportCsv(BuildContext context, WidgetRef ref, dynamic backupService) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    final count = await backupService.importFromCsvString(content);
    ref.invalidate(transactionsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $count transactions from CSV ✓'), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _exportAllCsv(BuildContext context, WidgetRef ref) async {
    final txs = ref.read(transactionsProvider);

    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export'), duration: Duration(seconds: 4)),
      );
      return;
    }

    final backup = ref.read(backupServiceProvider);
    final file = await backup.exportJsonBackup();
    await backup.shareBackupFile(file);
  }

  void _confirmResetAllData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase All Data?'),
        content: const Text('Are you completely sure? This will delete all transactions, custom wallets, and reset the app. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expenseRed, foregroundColor: Colors.white),
            onPressed: () async {
              final storage = ref.read(storageServiceProvider);
              await storage.clearAllData();

              ref.invalidate(transactionsProvider);
              ref.invalidate(walletsProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(settingsProvider);
              ref.invalidate(recurringRulesProvider);
              ref.invalidate(notificationsProvider);

              if (ctx.mounted) Navigator.pop(ctx);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data has been reset ✓'), duration: Duration(seconds: 4)),
              );
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}
