import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/system_widget_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_capsule_toast.dart';

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
          // 1. Cyber-Vault Frosted Glass Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.surfaceContainer,
                  palette.primaryDark.withValues(alpha: isDark ? 0.75 : 0.85),
                  palette.primary.withValues(alpha: isDark ? 0.45 : 0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.primaryDark.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CYBER-VAULT DATA HUB',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AES-256 Encrypted Local SQLite',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGreenLight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primaryGreenLight),
                          SizedBox(width: 4),
                          Text(
                            'Healthy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildVaultChip('📝', '${transactions.length}', 'Records')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildVaultChip('🏦', '${wallets.length}', 'Accounts')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildVaultChip('🏷️', '${categories.length}', 'Categories')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildVaultChip('🔁', '${recurring.length}', 'Rules')),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lastSyncTime != null
                              ? 'Last Backup: ${_lastSyncTime!.substring(0, 16).replaceAll('T', ' ')}'
                              : 'Local SQLite Database: Healthy & Encrypted',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

          // 3. Section: 2-Column Bento Action Grid
          _buildSectionHeader('LOCAL ENGINES & EXPORT HUBS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: JSON Data Vault
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.data_object_rounded, size: 20, color: palette.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'JSON Vault',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete database state & app settings.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _exportJsonBackup(context, ref),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Export Vault', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            side: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _confirmRestore(context, ref, backupService),
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: const Text('Restore File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Column 2: Spreadsheet Engine
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.table_chart_rounded, size: 20, color: AppColors.warningAmber),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CSV Engine',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Excel, Sheets & bank CSV statements.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warningAmber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _exportAllCsv(context, ref),
                          icon: const Icon(Icons.table_view_rounded, size: 16),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            side: BorderSide(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _pickAndImportCsv(context, ref, backupService),
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('Import CSV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
      TopCapsuleToast.show(
        context,
        title: success ? 'Connected to Google Drive ✓' : 'Google sign-in cancelled',
        isSuccess: success,
      );
    } on GoogleAuthException catch (e) {
      if (!mounted) return;
      if (e.isDeveloperError10) {
        _showOAuthTokenDialog();
      } else {
        TopCapsuleToast.show(
          context,
          title: e.message,
          isSuccess: false,
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
              TopCapsuleToast.show(
                context,
                title: 'Connected to Google Drive successfully ✓',
                isSuccess: true,
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
        TopCapsuleToast.show(
          context,
          title: success ? 'Zero-knowledge backup saved to Google Drive ✓' : 'Sync failed',
          isSuccess: success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        TopCapsuleToast.show(
          context,
          title: 'Backup error: $e',
          isSuccess: false,
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
        TopCapsuleToast.show(
          context,
          title: backup != null ? 'Restored all data from Google Drive ✓' : 'No cloud backup found on Google Drive',
          isSuccess: backup != null,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        TopCapsuleToast.show(
          context,
          title: 'Restore error: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _signOut() async {
    await CloudSyncService().signOut();
    await _checkAuthStatus();
    if (mounted) {
      TopCapsuleToast.show(
        context,
        title: 'Disconnected from Google Drive',
        isSuccess: true,
      );
    }
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

  Widget _buildVaultChip(String emoji, String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            count,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportJsonBackup(BuildContext context, WidgetRef ref) async {
    try {
      final backup = ref.read(backupServiceProvider);
      final file = await backup.exportJsonBackup();
      await backup.shareBackupFile(file, subject: 'Pocket Complete Financial Backup');
      if (!context.mounted) return;
      TopCapsuleToast.show(
        context,
        title: 'JSON Vault Exported ✓',
        subtitle: 'Encrypted backup ready to share',
        isSuccess: true,
      );
    } catch (e) {
      if (!context.mounted) return;
      TopCapsuleToast.show(
        context,
        title: 'Export failed: $e',
        isSuccess: false,
      );
    }
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
                TopCapsuleToast.show(
                  context,
                  title: 'Database restored successfully ✓',
                  subtitle: 'All records recovered',
                  isSuccess: true,
                );
              } else {
                if (!context.mounted) return;
                TopCapsuleToast.show(
                  context,
                  title: 'Failed to restore database',
                  subtitle: 'Invalid backup file structure',
                  isSuccess: false,
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
    TopCapsuleToast.show(
      context,
      title: 'Imported $count transactions from CSV ✓',
      isSuccess: true,
    );
  }

  Future<void> _exportAllCsv(BuildContext context, WidgetRef ref) async {
    final txs = ref.read(transactionsProvider);

    if (txs.isEmpty) {
      TopCapsuleToast.show(
        context,
        title: 'No transactions to export',
        isSuccess: false,
      );
      return;
    }

    try {
      final backup = ref.read(backupServiceProvider);
      final file = await backup.exportTransactionsCsv();
      await backup.shareBackupFile(file, subject: 'Pocket Transactions CSV Export');
      if (!context.mounted) return;
      TopCapsuleToast.show(
        context,
        title: 'Transactions CSV Exported ✓',
        subtitle: '${txs.length} transactions included',
        isSuccess: true,
      );
    } catch (e) {
      if (!context.mounted) return;
      TopCapsuleToast.show(
        context,
        title: 'Export failed: $e',
        isSuccess: false,
      );
    }
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
              TopCapsuleToast.show(
                context,
                title: 'All data has been reset ✓',
                isSuccess: true,
              );
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}
