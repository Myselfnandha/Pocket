import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_sync_service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Cloud Sync'),
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

          // 2. Supabase Free Cloud Database Sync
          _buildSectionHeader('SUPABASE FREE CLOUD DATABASE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
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
                        _isSupabaseConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
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
                                'Supabase PostgreSQL Cloud',
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
                                  _isSupabaseConnected ? 'CONNECTED' : 'OFFLINE',
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
                            _lastSyncTime != null
                                ? 'Last synced: ${_lastSyncTime!.substring(0, 16).replaceAll('T', ' ')}'
                                : 'Connect free Supabase database to sync across devices',
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
                if (!_isSupabaseConnected)
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
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Connect Supabase Database', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                else ...[
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _disconnectSupabase,
                      icon: const Icon(Icons.link_off_rounded, size: 14, color: AppColors.expenseRed),
                      label: const Text('Disconnect Database', style: TextStyle(fontSize: 11, color: AppColors.expenseRed)),
                    ),
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
                          content: Text('Failed to export backup: $e'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded, color: AppColors.infoBlue),
                  title: const Text('Restore Database from Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Restore complete state from a previously saved Pocket JSON backup'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _confirmRestore(context, ref, backupService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Section: Data Import & Export
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

          // 5. Section: Danger Zone
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
            Text('Connect Supabase Cloud', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your free Supabase project credentials to enable instant cloud backup & sync:',
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
                  content: Text(success ? 'Connected to Supabase Cloud ✓' : 'Failed to connect. Check credentials.'),
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
          content: Text(success ? 'Synced database to Supabase Cloud ✓' : 'Sync failed. Check connection or table setup.'),
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
      await ref.read(transactionsProvider.notifier).refreshFromDisk();
      await ref.read(walletsProvider.notifier).refreshFromDisk();
      await ref.read(categoriesProvider.notifier).refreshFromDisk();
      await ref.read(notificationsProvider.notifier).refreshFromDisk();
    }
    await _checkSupabaseStatus();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(success ? 'Restored database from Supabase Cloud ✓' : 'Restore failed. No cloud backup found.'),
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
          content: Text('Disconnected from Supabase Cloud'),
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
              await storage.clearAllData();

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
