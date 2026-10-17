import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/nlp_quick_add_modal.dart';
import '../../widgets/user_avatar_widget.dart';
import '../../widgets/waving_hand_emoji.dart';
import '../../widgets/pending_transactions_capsule.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Consumer(
          builder: (context, ref, child) {
            final palette = ref.watch(activePaletteProvider);
            return InkWell(
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatarWidget(
                      avatarId: settings.selectedAvatarId,
                      size: 38,
                      glowColor: palette.primary,
                      fallbackInitial: settings.userName,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hi, ${settings.userName} ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const WavingHandEmoji(fontSize: 18),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryGreenLight, size: 22),
            tooltip: 'Natural Language Entry',
            onPressed: () => NlpQuickAddModal.show(context),
          ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Pinned Area: Hero Balance Card + Quick Hub + Capsule + Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Summary Card (with Integrated Accounts Carousel)
                    const BalanceCard(),
                    const SizedBox(height: 14),

                    // Quick Hub Row: Recurring & Debts
                    Consumer(
                      builder: (context, ref, _) {
                        final recurringRules = ref.watch(recurringRulesProvider);
                        final activeRulesCount = recurringRules.where((r) => r.isActive).length;
                        final totalLent = ref.watch(totalLentProvider);
                        final totalBorrowed = ref.watch(totalBorrowedProvider);
                        final netDebt = totalLent - totalBorrowed;

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
                                            Text(
                                              netDebt >= 0
                                                  ? '+${settings.formatCurrency(netDebt)}'
                                                  : '-${settings.formatCurrency(netDebt.abs())}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: netDebt >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
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
                          ],
                        );
                      },
                    ),

                    // Detected Payments Capsule
                    const PendingTransactionsCapsule(),
                    const SizedBox(height: 14),

                    // Section Header: Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/transactions'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See All',
                                style: TextStyle(
                                  color: AppColors.primaryGreenLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.primaryGreenLight,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Containerized Scrolling Recent Activity Section with Day Indicators
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final allTxs = ref.watch(transactionsProvider);
                      final displayList = allTxs.take(30).toList();

                      if (displayList.isEmpty) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '🌿',
                                  style: TextStyle(fontSize: 42),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions logged yet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap + button below to record an entry',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Group recent transactions by day header
                      final Map<String, List<TransactionModel>> grouped = {};
                      for (final tx in displayList) {
                        final key = _formatDateHeader(tx.date);
                        grouped.putIfAbsent(key, () => []).add(tx);
                      }

                      final groupKeys = grouped.keys.toList();

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: groupKeys.length,
                          itemBuilder: (context, groupIndex) {
                            final dateKey = groupKeys[groupIndex];
                            final txs = grouped[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Day Indicator Header Bar
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF191D26)
                                        : const Color(0xFFF4F6FA),
                                    border: Border(
                                      top: groupIndex > 0
                                          ? BorderSide(
                                              color: isDark
                                                  ? AppColors.darkCardBorder
                                                  : AppColors.lightCardBorder,
                                              width: 1,
                                            )
                                          : BorderSide.none,
                                      bottom: BorderSide(
                                        color: isDark
                                            ? AppColors.darkCardBorder
                                            : AppColors.lightCardBorder,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateKey.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${txs.length} ${txs.length == 1 ? 'entry' : 'entries'}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Transaction Tiles for this date
                                for (int i = 0; i < txs.length; i++) ...[
                                  TransactionTile(
                                    transaction: txs[i],
                                    onTap: () => context.push(
                                      '/transaction-detail',
                                      extra: txs[i],
                                    ),
                                  ),
                                  if (i < txs.length - 1)
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? AppColors.darkCardBorder
                                          : AppColors.lightCardBorder,
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('d MMM').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('d MMM').format(dt)}';
    }
    if (dt.year == now.year) {
      return DateFormat('EEE, d MMM').format(dt);
    }
    return DateFormat('d MMM yyyy').format(dt);
  }
}
