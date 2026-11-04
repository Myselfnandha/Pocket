import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_capsule_toast.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _isExporting = false;

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
        title: const Text('Data Management'),
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
                            'LOCAL DATA VAULT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AES-256 Encrypted Local Storage',
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
                            'Secure',
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
                        Icons.lock_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'All data is encrypted with AES-256 at rest on this device',
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

          // 2. Section: Backup & Export
          _buildSectionHeader('BACKUP & EXPORT'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.file_download_outlined, color: palette.primary),
                    ),
                    title: const Text('Export JSON Backup', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Complete encrypted database snapshot'),
                    trailing: _isExporting
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(palette.primary)))
                        : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.primary),
                    onTap: _isExporting ? null : () => _exportJsonBackup(backupService, palette),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_chart_outlined, color: Color(0xFF00BCD4)),
                    ),
                    title: const Text('Export CSV Transactions', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Spreadsheet-compatible format'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: const Color(0xFF00BCD4)),
                    onTap: () => _exportCsvTransactions(backupService),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFF5252)),
                    ),
                    title: const Text('Generate PDF Report', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Full year-to-date financial summary'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: const Color(0xFFFF5252)),
                    onTap: () => _generatePdfReport(backupService),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Section: Restore from File
          _buildSectionHeader('RESTORE FROM BACKUP'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.file_upload_outlined, color: palette.primary),
                    ),
                    title: const Text('Restore from JSON', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Upload encrypted backup file'),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.primary),
                    onTap: () => _restoreFromJson(backupService),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Section: Info
          _buildSectionHeader('STORAGE INFORMATION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('🔐', 'Encryption', 'AES-256-CBC (Hardware Keystore)'),
                const SizedBox(height: 12),
                _buildInfoRow('📍', 'Location', 'Local Device Only (On-Device)'),
                const SizedBox(height: 12),
                _buildInfoRow('☁️', 'Cloud Sync', 'Disabled (Privacy First)'),
                const SizedBox(height: 12),
                _buildInfoRow('🔄', 'Auto-Sync', 'No Remote Sync'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildVaultChip(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.primaryGreenLight,
        ),
      ),
    );
  }

  Future<void> _exportJsonBackup(dynamic backupService, dynamic palette) async {
    if (mounted) {
      setState(() => _isExporting = true);
    }
    try {
      await backupService.exportJsonBackup();
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✓ JSON backup exported',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✗ Export failed: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportCsvTransactions(dynamic backupService) async {
    try {
      await backupService.exportCsvTransactions();
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✓ CSV transactions exported',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✗ Export failed: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _generatePdfReport(dynamic backupService) async {
    try {
      await backupService.generatePdfReport();
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✓ PDF report generated',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✗ Report generation failed: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _restoreFromJson(dynamic backupService) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          await backupService.restoreFromJson(filePath);
          if (mounted) {
            TopCapsuleToast.show(
              context,
              message: '✓ Database restored from backup',
              duration: const Duration(seconds: 2),
            );
            ref.invalidate(transactionsProvider);
            ref.invalidate(walletsProvider);
            ref.invalidate(categoriesProvider);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        TopCapsuleToast.show(
          context,
          message: '✗ Restore failed: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}
