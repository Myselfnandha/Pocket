import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pending_transaction_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/pending_transactions_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auto_import_service.dart';
import '../../widgets/auto_import_guide_modal.dart';
import '../../widgets/top_capsule_toast.dart';

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
            // Top Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.primary.withValues(alpha: 0.22),
                    palette.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.4),
                  width: 1.5,
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
                          color: palette.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bolt_rounded, color: palette.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Real-Time Capture Suite',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _permissions.hasAnyActive ? 'Engine Active & Listening' : 'Setup Required',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _permissions.hasAnyActive ? Colors.greenAccent : Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Automatically intercepts payments from GPay, PhonePe, Paytm, and bank alerts with zero data leaving your phone. Deduplicated and reviewed before saving.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => showAutoImportGuideModal(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Launch Setup Walkthrough', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
              subtitle: 'Parses bank transaction SMS automatically',
              isActive: _permissions.isSmsListenerEnabled,
              icon: Icons.sms_outlined,
              paletteColor: palette.primary,
              onTapAction: () async {
                await ref.read(autoImportServiceProvider).requestSmsPermission();
                _refreshPermissions();
              },
              actionLabel: _permissions.isSmsListenerEnabled ? 'Refresh' : 'Grant Access',
            ),
            const SizedBox(height: 28),

            // Testing & Simulation Section
            const Text(
              'TEST & SIMULATION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF22222B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulate Real-Time Payment',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test the dynamic review capsule and bottom sheet without making a live payment.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(pendingTransactionsProvider.notifier).addPending(
                                PendingTransactionModel(
                                  id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
                                  amount: 450.0,
                                  merchant: 'Swiggy',
                                  appSource: 'Google Pay',
                                  refId: '423812903123',
                                  date: DateTime.now(),
                                  suggestedCategoryId: 'food_dining',
                                  detectionSource: 'notification',
                                ),
                              );
                          TopCapsuleToast.show(
                            context,
                            title: 'Simulated GPay: ₹450 to Swiggy',
                            icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                          );
                        },
                        icon: const Icon(Icons.fastfood_outlined, size: 16),
                        label: const Text('Simulate Swiggy (₹450)'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(pendingTransactionsProvider.notifier).addPending(
                                PendingTransactionModel(
                                  id: 'sim_uber_${DateTime.now().millisecondsSinceEpoch}',
                                  amount: 280.0,
                                  merchant: 'Uber Rides',
                                  appSource: 'PhonePe',
                                  refId: '429182391024',
                                  date: DateTime.now(),
                                  suggestedCategoryId: 'transport',
                                  detectionSource: 'screen_reader',
                                ),
                              );
                          TopCapsuleToast.show(
                            context,
                            title: 'Simulated PhonePe: ₹280 to Uber',
                            icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                          );
                        },
                        icon: const Icon(Icons.directions_car_outlined, size: 16),
                        label: const Text('Uber (₹280)'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
        border: Border.all(
          color: isActive ? paletteColor.withValues(alpha: 0.4) : (isDark ? Colors.white10 : Colors.black12),
        ),
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
