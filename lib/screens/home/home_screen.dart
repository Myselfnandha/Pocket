import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/detected_transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../services/upi_detection_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/quick_add_transaction_dialog.dart';
import '../../widgets/transaction_review_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize UPI Detection service and register deep-link callback
    UpiDetectionService.initialize();
    UpiDetectionService.onDeepLinkReceived = (deepLink) {
      _handleDeepLink(deepLink);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialDeepLink();
      ref.read(pendingDetectedTransactionsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(pendingDetectedTransactionsProvider.notifier).refresh();
    }
  }

  Future<void> _checkInitialDeepLink() async {
    final link = await UpiDetectionService.getInitialDeepLink();
    if (link != null && link.isNotEmpty) {
      _handleDeepLink(link);
    }
  }

  void _handleDeepLink(String deepLink) {
    try {
      final uri = Uri.parse(deepLink);
      if (uri.scheme == 'pocket' && uri.host == 'review_transaction') {
        final id = uri.queryParameters['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        final amount = double.tryParse(uri.queryParameters['amount'] ?? '') ?? 0.0;
        final merchant = uri.queryParameters['merchant'] ?? 'UPI Payment';
        final app = uri.queryParameters['app'] ?? 'UPI';
        final typeStr = uri.queryParameters['type'] ?? 'expense';
        final type = (typeStr == 'income') ? TransactionType.income : TransactionType.expense;
        final ts = int.tryParse(uri.queryParameters['timestamp'] ?? '') ?? DateTime.now().millisecondsSinceEpoch;

        final detected = DetectedTransactionModel(
          id: id,
          amount: amount,
          merchant: merchant,
          sourceApp: app,
          type: type,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          rawText: 'Deep link notification from $app',
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          TransactionReviewModal.show(context, detected);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final todayTxs = ref.watch(todayTransactionsProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final pendingDetectedTxs = ref.watch(pendingDetectedTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormat = NumberFormat('#,##0.00');

    // Calculate daily average for the month so far
    final dayOfMonth = DateTime.now().day;
    final dailyAvg = dayOfMonth > 0 ? monthlyStats.totalExpense / dayOfMonth : 0.0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Opacity(
              opacity: val,
              child: Transform.translate(
                offset: Offset(0, (1 - val) * 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        settings.userName.isNotEmpty
                            ? settings.userName[0].toUpperCase()
                            : 'N',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hi, ${settings.userName} 👋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 24),
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QuickAddTransactionDialog.show(context),
        backgroundColor: AppColors.primaryGreenLight,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tooltip: 'Quick Add Transaction',
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Quick Add',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(pendingDetectedTransactionsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Pending Real-Time UPI Detection Banner
              if (pendingDetectedTxs.isNotEmpty) ...[
                _buildPendingDetectedBanner(context, ref, pendingDetectedTxs, isDark),
                const SizedBox(height: 14),
              ],

              // 1. Balance Summary Card
              const BalanceCard(),
              const SizedBox(height: 16),

              // 2. Quick Stats Row (Daily Average & Monthly Savings)
              Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppColors.accentOrange,
                      label: 'Daily Average',
                      value: '${settings.currencySymbol}${currencyFormat.format(dailyAvg)}',
                      valueColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.savings_outlined,
                      iconColor: AppColors.incomeGreen,
                      label: 'Monthly Savings',
                      value: '${settings.currencySymbol}${currencyFormat.format(monthlyStats.netSavings)}',
                      valueColor: monthlyStats.netSavings >= 0
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2.5 Quick Hub Row: Recurring & Debts
              Consumer(
                builder: (context, ref, _) {
                  final recurringRules = ref.watch(recurringRulesProvider);
                  final activeRulesCount = recurringRules.where((r) => r.isActive).length;

                  return Row(
                    children: [
                      // Recurring Dues Card Button
                      Expanded(
                        child: InkWell(
                          onTap: () => context.push('/recurring-rules'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF18221B) : const Color(0xFFEDF7F1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryGreenLight.withValues(alpha: isDark ? 0.3 : 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreenLight.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.autorenew_rounded, size: 18, color: AppColors.primaryGreenLight),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recurring Dues',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$activeRulesCount active',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryGreenLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Debts & Loans Card Button
                      Expanded(
                        child: InkWell(
                          onTap: () => context.push('/debts'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141E28) : const Color(0xFFEEF5FB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.infoBlue.withValues(alpha: isDark ? 0.3 : 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoBlue.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.handshake_outlined, size: 18, color: AppColors.infoBlue),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Debts & Loans',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Consumer(
                                        builder: (context, ref, _) {
                                          final totalLent = ref.watch(totalLentProvider);
                                          final totalBorrowed = ref.watch(totalBorrowedProvider);
                                          final netDebt = totalLent - totalBorrowed;
                                          final isPositive = netDebt >= 0;
                                          return Text(
                                            '${isPositive ? '+' : '-'}${settings.currencySymbol}${netDebt.abs().toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isPositive ? AppColors.incomeGreen : AppColors.expenseRed,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. Section Title: Today's Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Activity",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/transactions'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Transaction List
              if (todayTxs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions yet today',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the Quick Add button below to log an expense or income.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreenLight,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Log First Transaction', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        onPressed: () => QuickAddTransactionDialog.show(context),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todayTxs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = todayTxs[index];
                    return TransactionTile(
                      transaction: tx,
                      onTap: () => context.push('/transaction/${tx.id}'),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingDetectedBanner(
    BuildContext context,
    WidgetRef ref,
    List<DetectedTransactionModel> pendingList,
    bool isDark,
  ) {
    final first = pendingList.first;
    final count = pendingList.length;
    final currencySymbol = ref.watch(settingsProvider).currencySymbol;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E20) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryGreenLight.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreenLight.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      count > 1 ? '$count Payments Detected' : 'New ${first.sourceApp} Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$currencySymbol${first.amount.toStringAsFixed(2)} at ${first.merchant}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFD4EAD6) : const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              TransactionReviewModal.show(context, first);
            },
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
