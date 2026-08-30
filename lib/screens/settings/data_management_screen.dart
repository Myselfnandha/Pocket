import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/system_widget_service.dart';
import '../../theme/app_theme.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _isSignedIn = false;
  String? _userEmail;
  String? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final service = CloudSyncService();
    await service.init();
    final signedIn = service.isSignedIn;
    final email = service.userEmail;
    final lastSync = await service.getLastSyncTime();

    if (mounted) {
      setState(() {
        _isSignedIn = signedIn;
        _userEmail = email;
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
    final palette = ref.watch(activePaletteProvider);

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

          // 2. Section: Real Authentication & Cloud Sync
          _buildSectionHeader('CLOUD BACKUP & AUTHENTICATION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSignedIn
                    ? palette.primary.withValues(alpha: 0.5)
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
                        color: _isSignedIn
                            ? palette.primary.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSignedIn ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                        color: _isSignedIn ? palette.primary : Colors.grey,
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
                                _isSignedIn ? 'Authenticated Cloud' : 'Cloud Database Sync',
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
                                  color: _isSignedIn
                                      ? palette.primary.withValues(alpha: 0.18)
                                      : Colors.grey.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isSignedIn ? 'AUTHENTICATED' : 'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: _isSignedIn ? palette.primary : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userEmail != null
                                ? 'User: $_userEmail'
                                : (_lastSyncTime != null
                                    ? 'Last synced: ${_lastSyncTime!.substring(0, 16).replaceAll('T', ' ')}'
                                    : 'Sign in to automatically sync database across all devices'),
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

                // Action Buttons for Sign-In vs Sync
                if (!_isSignedIn) ...[
                  // 1-Tap Google Sign-In
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 1,
                      ),
                      onPressed: _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Color(0xFF4285F4)),
                      label: const Text('Sign In with Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showOAuthTokenDialog,
                      icon: const Icon(Icons.key_rounded, size: 13, color: Colors.grey),
                      label: const Text('Connect via Google Token / Key', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
                ] else ...[
                  // User is Authenticated: Backup & Restore
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSyncing ? null : _syncToCloud,
                          icon: _isSyncing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: Text(_isSyncing ? 'Syncing...' : 'Backup to Drive', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.primary,
                            side: BorderSide(color: palette.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSyncing ? null : _restoreFromCloud,
                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                          label: const Text('Restore Drive', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded, size: 14, color: AppColors.expenseRed),
                        label: const Text('Disconnect Account', style: TextStyle(fontSize: 11.5, color: AppColors.expenseRed)),
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

  Future<void> _signInWithGoogle() async {
    try {
      final success = await CloudSyncService().signInWithGoogle();
      await _checkAuthStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(success ? 'Connected to Google Drive successfully ✓' : 'Google sign-in cancelled'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on GoogleAuthException catch (e) {
      if (!mounted) return;
      if (e.isDeveloperError10) {
        _showOAuthTokenDialog();
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(e.message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showOAuthTokenDialog();
    }
  }

  void _showOAuthTokenDialog() {
    final emailController = TextEditingController(text: _userEmail ?? '');
    final tokenController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.primaryGreenLight),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Google Drive Authorization',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in directly with your Google account email and OAuth Access Token (Bearer Token) to enable zero-knowledge cloud backup.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Google Account Email',
                  hintText: 'user@gmail.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Google Drive Access Token',
                  hintText: 'ya29.a0A...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final email = emailController.text.trim();
              final token = tokenController.text.trim();
              if (email.isEmpty || token.isEmpty) return;

              await CloudSyncService().setManualAccessToken(token: token, email: email);
              if (ctx.mounted) Navigator.pop(ctx);
              await _checkAuthStatus();

              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Connected to Google Drive successfully ✓'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Connect & Authorize', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToCloud() async {
    setState(() => _isSyncing = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final success = await CloudSyncService().uploadBackupToCloud(storage);
      await _checkAuthStatus();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(success ? 'Zero-knowledge backup saved to Google Drive ✓' : 'Sync failed.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Backup error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _restoreFromCloud() async {
    setState(() => _isSyncing = true);
    try {
      final backup = await CloudSyncService().downloadBackupFromCloud();
      if (backup != null) {
        final storage = ref.read(storageServiceProvider);
        await storage.restoreDatabase(backup);

        ref.invalidate(transactionsProvider);
        ref.invalidate(walletsProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(settingsProvider);
        ref.invalidate(recurringRulesProvider);
        ref.invalidate(debtsProvider);
        ref.invalidate(categoryBudgetsProvider);
        ref.invalidate(goalsProvider);

        final updatedSettings = storage.getSettings();
        SystemWidgetService.updateWidgetData(
          totalBalance: storage.getWallets().fold(0.0, (sum, w) => sum + w.currentBalance),
          todayExpense: 0.0,
          currencySymbol: updatedSettings.currencySymbol,
          wallets: storage.getWallets(),
        );
      }

      await _checkAuthStatus();

      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(backup != null ? 'Restored all data from Google Drive ✓' : 'No cloud backup found on Google Drive.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Restore error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await CloudSyncService().signOut();
    await _checkAuthStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Disconnected from Google Drive'),
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
