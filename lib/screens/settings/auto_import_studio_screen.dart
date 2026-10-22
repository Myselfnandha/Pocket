import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/core_providers.dart';
import '../../providers/pending_transactions_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auto_import_service.dart';
import '../../widgets/auto_import_guide_modal.dart';
import '../../widgets/sms_inbox_scanner_sheet.dart';

class AutoImportStudioScreen extends ConsumerStatefulWidget {
  const AutoImportStudioScreen({super.key});

  @override
  ConsumerState<AutoImportStudioScreen> createState() => _AutoImportStudioScreenState();
}

class _AutoImportStudioScreenState extends ConsumerState<AutoImportStudioScreen> with WidgetsBindingObserver {
  AutoImportPermissions _permissions = const AutoImportPermissions();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
      ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
    }
  }

  Future<void> _refreshPermissions() async {
    final service = ref.read(autoImportServiceProvider);
    final perms = await service.checkPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Import Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Setup Guide',
            onPressed: () => showAutoImportGuideModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _refreshPermissions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPermissions,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Live Listener Modules
            const Text(
              'REAL-TIME LISTENERS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // 1. Notification Listener Card
            _buildListenerCard(
              context: context,
              title: 'Notification Listener',
              subtitle: 'Captures push alerts from UPI and banking apps',
              isActive: _permissions.isNotificationListenerEnabled,
              icon: Icons.notifications_active_outlined,
              paletteColor: palette.primary,
              onTapAction: () => ref.read(autoImportServiceProvider).openNotificationSettings(),
              actionLabel: 'Open Settings',
            ),
            const SizedBox(height: 12),

            // 2. Accessibility Screen Reader Card
            _buildListenerCard(
              context: context,
              title: 'Payment Screen Reader',
              subtitle: 'Zero-click reading of in-app green tick payment success',
              isActive: _permissions.isAccessibilityEnabled,
              icon: Icons.visibility_outlined,
              paletteColor: palette.primary,
              onTapAction: () => ref.read(autoImportServiceProvider).openAccessibilitySettings(),
              actionLabel: 'Open Settings',
            ),
            const SizedBox(height: 12),

            // 3. Screenshot Auto-Watcher
            _buildListenerCard(
              context: context,
              title: 'Screenshot Auto-Watcher',
              subtitle: 'Automatically scans newly captured payment receipts',
              isActive: _permissions.isScreenshotWatcherActive,
              icon: Icons.camera_alt_outlined,
              paletteColor: palette.primary,
              trailingWidget: Switch(
                value: _permissions.isScreenshotWatcherActive,
                activeThumbColor: palette.primary,
                onChanged: (val) async {
                  await ref.read(autoImportServiceProvider).setScreenshotWatcherEnabled(val);
                  _refreshPermissions();
                },
              ),
            ),
            const SizedBox(height: 12),

            // 4. SMS Bank Alerts
            _buildListenerCard(
              context: context,
              title: 'SMS Bank Alerts',
              subtitle: 'Parses bank transaction SMS automatically in real-time',
              isActive: _permissions.isSmsListenerEnabled,
              icon: Icons.sms_outlined,
              paletteColor: palette.primary,
              onTapAction: () async {
                await ref.read(autoImportServiceProvider).requestSmsPermission();
                _refreshPermissions();
              },
              actionLabel: _permissions.isSmsListenerEnabled ? 'Active' : 'Grant Access',
            ),
            const SizedBox(height: 12),

            // 5. SMS Auto-Save Directly Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.flash_on_rounded, color: palette.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Log SMS Directly',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Instantly records detected bank SMS without waiting for manual confirmation',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: ref.watch(settingsProvider).autoSaveSms,
                    activeThumbColor: palette.primary,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).setAutoSaveSms(val);
                      await ref.read(autoImportServiceProvider).setAutoSaveSmsPreference(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6. Scan SMS Inbox Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.mark_email_read_outlined, color: palette.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scan SMS Messages',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan past SMS inbox to backfill transactions',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => SmsInboxScannerSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Scan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListenerCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isActive,
    required IconData icon,
    required Color paletteColor,
    VoidCallback? onTapAction,
    String? actionLabel,
    Widget? trailingWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22222B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isActive ? paletteColor : Colors.grey).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? paletteColor : Colors.grey, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.greenAccent : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (trailingWidget != null)
            trailingWidget
          else if (onTapAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTapAction,
              style: TextButton.styleFrom(
                foregroundColor: paletteColor,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
