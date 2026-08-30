import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/system_widget_service.dart';
import '../../theme/app_theme.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _isSupabaseConnected = false;
  String? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkSupabaseStatus();
  }

  Future<void> _checkSupabaseStatus() async {
    final service = SupabaseSyncService();
    final connected = await service.init();
    final lastSync = await service.getLastSyncTime();
    if (mounted) {
      setState(() {
        _isSupabaseConnected = connected;
        _lastSyncTime = lastSync;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final wallets = ref.watch(walletsProvider);
    final categories = ref.watch(categoriesProvider);
    final recurring = ref.watch(recurringRulesProvider);
    final backupService = ref.watch(backupServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncService = SupabaseSyncService();
    final user = syncService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Cloud Sync'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Overview Metric Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Transactions', '${transactions.length}', isDark),
                _buildMetric('Wallets', '${wallets.length}', isDark),
                _buildMetric('Categories', '${categories.length}', isDark),
                _buildMetric('Recurring', '${recurring.length}', isDark),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Section: Cloud Sync & Backup
          _buildSectionHeader('CLOUD BACKUP & GOOGLE SYNC'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSupabaseConnected
                    ? AppColors.primaryGreenLight.withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
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
                        color: _isSupabaseConnected
                            ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSupabaseConnected ? Icons.cloud_done_rounded : Icons.cloud_outlined,
                        color: _isSupabaseConnected ? AppColors.primaryGreenLight : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user != null ? 'Google Cloud Sync' : 'Cloud Database Sync',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isSupabaseConnected
                                      ? AppColors.primaryGreenLight.withValues(alpha: 0.18)
                                      : Colors.grey.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isSupabaseConnected ? (user != null ? 'GOOGLE AUTH' : 'CONNECTED') : 'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: _isSupabaseConnected ? AppColors.primaryGreenLight : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email != null
                                ? 'Account: ${user!.email}'
                                : (_lastSyncTime != null
                                    ? 'Last synced: ${_lastSyncTime!.substring(0, 16).replaceAll('T', ' ')}'
                                    : '1-Tap Google Sign-in to sync database across devices'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 12),
                if (!_isSupabaseConnected) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenLight,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _showSupabaseConfigDialog,
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: const Text('Connect Free Cloud Database', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreenLight,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSyncing ? null : _syncToSupabase,
                          icon: _isSyncing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: Text(_isSyncing ? 'Syncing...' : 'Sync to Cloud', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.infoBlue,
                            side: const BorderSide(color: AppColors.infoBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSyncing ? null : _restoreFromSupabase,
                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                          label: const Text('Restore Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined, size: 14, color: AppColors.infoBlue),
                        label: Text(user != null ? 'Switch Google Account' : 'Sign In With Google', style: const TextStyle(fontSize: 11, color: AppColors.infoBlue)),
                      ),
                      TextButton.icon(
                        onPressed: _disconnectSupabase,
                        icon: const Icon(Icons.link_off_rounded, size: 14, color: AppColors.expenseRed),
                        label: const Text('Disconnect', style: TextStyle(fontSize: 11, color: AppColors.expenseRed)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Section: Local Backup & Restore
          _buildSectionHeader('LOCAL BACKUP & RESTORE'),
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
                  leading: const Icon(Icons.save_alt_rounded, color: AppColors.primaryGreenLight),
                  title: const Text('Export JSON Database Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export all transactions, wallets, rules, and settings to a JSON file'),
                  trailing: const Icon(Icons.share_outlined, size: 20),
                  onTap: () async {
                    try {
                      final file = await backupService.exportJsonBackup();
                      await backupService.shareBackupFile(file);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Backup exported successfully ✓'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Export failed: $e'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ListTile(
                  leading: const Icon(Icons.restore_page_rounded, color: AppColors.infoBlue),
                  title: const Text('Restore from JSON Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Import and replace current data with a saved .json file'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _confirmRestore(context, ref, backupService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Section: CSV Spreadsheets
          _buildSectionHeader('CSV SPREADSHEETS (EXCEL / SHEETS)'),
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
                  leading: const Icon(Icons.table_chart_outlined, color: AppColors.warningAmber),
                  title: const Text('Export Transactions (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Export all transaction records for spreadsheets'),
                  trailing: const Icon(Icons.share_outlined, size: 20),
                  onTap: () => _exportAllCsv(context, ref),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: AppColors.warningAmber),
                  title: const Text('Import Transactions (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Import records from bank/fintech CSV files'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickAndImportCsv(context, ref, backupService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Danger Zone: Erase Data
          _buildSectionHeader('DANGER ZONE'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.expenseRed.withValues(alpha: 0.5),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expenseRed),
              title: const Text('Reset All Data', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.expenseRed)),
              subtitle: const Text('Erase all transactions, wallets, and settings permanently'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.expenseRed),
              onTap: () => _confirmResetAllData(context, ref),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSupabaseConfigDialog() {
    final urlController = TextEditingController();
    final keyController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: AppColors.primaryGreenLight),
            SizedBox(width: 10),
            Text('Connect Cloud Sync', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your free Supabase project credentials to enable instant multi-device backup & sync:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://xyzcompany.supabase.co',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Anon Public Key',
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final url = urlController.text.trim();
              final key = keyController.text.trim();
              if (url.isEmpty || key.isEmpty) return;

              final success = await SupabaseSyncService().connect(url: url, anonKey: key);
              if (ctx.mounted) Navigator.pop(ctx);
              _checkSupabaseStatus();

              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(success ? 'Connected to Cloud Database ✓' : 'Failed to connect. Check credentials.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final success = await SupabaseSyncService().signInWithGoogle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Opening Google Sign-in browser...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _syncToSupabase() async {
    setState(() => _isSyncing = true);
    final storage = ref.read(storageServiceProvider);
    final success = await SupabaseSyncService().backupToCloud(storage);
    await _checkSupabaseStatus();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(success ? 'Synced database to Cloud ✓' : 'Sync failed. Check connection or permissions.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _restoreFromSupabase() async {
    setState(() => _isSyncing = true);
    final storage = ref.read(storageServiceProvider);
    final success = await SupabaseSyncService().restoreFromCloud(storage);

    if (success) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(walletsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(recurringRulesProvider);
      ref.invalidate(debtsProvider);
      ref.invalidate(categoryBudgetsProvider);
    }

    await _checkSupabaseStatus();

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(success ? 'Restored all data from Cloud ✓' : 'Restore failed. No cloud backup found.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _disconnectSupabase() async {
    await SupabaseSyncService().disconnect();
    _checkSupabaseStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Disconnected from Cloud Database'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
        content: const Text('This will overwrite existing local data with the selected backup file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final success = await backupService.restoreFromJsonString(content);
              if (ctx.mounted) Navigator.pop(ctx);

              if (success) {
                ref.invalidate(transactionsProvider);
                ref.invalidate(walletsProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(settingsProvider);
                ref.invalidate(recurringRulesProvider);
                ref.invalidate(debtsProvider);
                ref.invalidate(categoryBudgetsProvider);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Database restored successfully ✓'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Failed to restore. Invalid backup file structure.'),
                    duration: Duration(seconds: 2),
                  ),
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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Imported $count transactions from CSV ✓'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportAllCsv(BuildContext context, WidgetRef ref) async {
    final txs = ref.read(transactionsProvider);

    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No transactions to export'),
          duration: Duration(seconds: 2),
        ),
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
              final settings = ref.read(settingsProvider);
              await storage.clearAllData();

              // Instantly clear & reset Android System Widget to ₹0.00 zero state
              await SystemWidgetService.clearWidgetData(settings.currencySymbol);

              ref.invalidate(transactionsProvider);
              ref.invalidate(walletsProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(settingsProvider);
              ref.invalidate(recurringRulesProvider);
              ref.invalidate(notificationsProvider);

              if (ctx.mounted) Navigator.pop(ctx);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('All data has been reset ✓'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}
