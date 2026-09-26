import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryWallet = wallets.isNotEmpty
        ? wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first)
        : null;

    final cardLast4 = (primaryWallet != null &&
            primaryWallet.accountNumber != null &&
            primaryWallet.accountNumber!.trim().isNotEmpty)
        ? (primaryWallet.accountNumber!.length >= 4
            ? primaryWallet.accountNumber!.substring(primaryWallet.accountNumber!.length - 4)
            : primaryWallet.accountNumber!)
        : '2026';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF1A1F2B) : Colors.white,
            isDark ? const Color(0xFF101319) : const Color(0xFFF3F6FA),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? palette.primary.withValues(alpha: 0.35)
              : palette.primary.withValues(alpha: 0.22),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: palette.primary.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Debit Card Header: Metallic EMV Chip + Contactless Symbol + Total Balance & Manage Link
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Metallic EMV Chip
                    Container(
                      width: 38,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE5C07B), Color(0xFFD19A66), Color(0xFFE5C07B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB8860B), width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 10,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 0.8, color: Colors.black26),
                          ),
                          Positioned(
                            right: 10,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 0.8, color: Colors.black26),
                          ),
                          Center(
                            child: Container(
                              width: 16,
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.black26, width: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Contactless Wave Icon
                    Transform.rotate(
                      angle: 1.5708,
                      child: Icon(
                        Icons.wifi_rounded,
                        size: 19,
                        color: palette.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                // Currency Pill + Manage Link
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        settings.currencyCode,
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => context.push('/wallets'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Large Card Typography: Label + Big Balance + Masked Card Digits
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          settings.formatCurrency(totalBalance),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card Number Masked Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222836) : const Color(0xFFE4E9F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '•••• $cardLast4',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                          letterSpacing: 1.1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Bento Metrics Row (Income | Expense | Today)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _CompactMetricChip(
                    label: 'Income',
                    amount: '+${settings.formatCompact(monthlyStats.totalIncome)}',
                    icon: Icons.arrow_downward_rounded,
                    accentColor: AppColors.incomeGreen,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactMetricChip(
                    label: 'Expense',
                    amount: '-${settings.formatCompact(monthlyStats.totalExpense)}',
                    icon: Icons.arrow_upward_rounded,
                    accentColor: AppColors.expenseRed,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactMetricChip(
                    label: 'Today',
                    amount: settings.formatCompact(monthlyStats.todayExpense),
                    icon: Icons.access_time_rounded,
                    accentColor: AppColors.accentOrange,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Compact Horizontal Accounts Chip Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: wallets.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == wallets.length) {
                    return InkWell(
                      onTap: () => context.push('/wallets'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 13,
                              color: palette.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final wallet = wallets[index];
                  return InkWell(
                    onTap: () => context.push('/wallets'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E232F)
                            : const Color(0xFFEBF0F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: wallet.isDefault
                              ? palette.primary.withValues(alpha: 0.45)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                          width: wallet.isDefault ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wallet.icon,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wallet.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (wallet.accountNumber != null && wallet.accountNumber!.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(
                              '(${wallet.maskedAccountNumber})',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            settings.formatCurrency(wallet.currentBalance),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: wallet.currentBalance >= 0
                                  ? (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary)
                                  : AppColors.expenseRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _CompactMetricChip extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color accentColor;
  final bool isDark;

  const _CompactMetricChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
