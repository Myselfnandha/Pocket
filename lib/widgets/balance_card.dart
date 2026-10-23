import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/settings_model.dart';
import '../models/wallet_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({super.key});

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  bool _isPeeking = false;

  void _togglePeek() {
    HapticFeedback.lightImpact();
    setState(() => _isPeeking = !_isPeeking);
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final liquidWallets = wallets.where((w) => w.walletType != WalletType.loan).toList();
    final palette = ref.watch(activePaletteProvider);
    final forecast = ref.watch(monthSpendForecastProvider);
    final budgetRemaining = ref.watch(totalBudgetRemainingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPrivacy = settings.widgetPrivacyMode && !_isPeeking;
    final displayBalanceStr = isPrivacy ? '••••••' : settings.formatCurrency(totalBalance);

    // Calculate Safe Daily Spend
    final daysRemaining = forecast.daysRemainingInMonth > 0 ? forecast.daysRemainingInMonth : 1;
    final safeDailySpend = (budgetRemaining > 0 ? budgetRemaining : 0.0) / daysRemaining;
    final netSavings = monthlyStats.netSavings;

    // Configurable 3rd Stat Chip
    final stat = settings.homeScreenWidgetStat;
    String thirdChipLabel = 'Today';
    String thirdChipAmount = settings.formatCompact(monthlyStats.todayExpense);
    IconData thirdChipIcon = Icons.access_time_rounded;
    Color thirdChipColor = AppColors.accentOrange;
    VoidCallback? thirdChipTap = () => context.push('/analytics');

    switch (stat) {
      case HomeScreenWidgetStat.balanceAndTodaySpend:
        thirdChipLabel = 'Today';
        thirdChipAmount = settings.formatCompact(monthlyStats.todayExpense);
        thirdChipIcon = Icons.access_time_rounded;
        thirdChipColor = AppColors.accentOrange;
        thirdChipTap = () => context.push('/analytics');
        break;
      case HomeScreenWidgetStat.netWorth:
        thirdChipLabel = 'Net Worth';
        final netWorth = ref.watch(netWorthSummaryProvider).totalNetWorth;
        thirdChipAmount = settings.formatCompact(netWorth);
        thirdChipIcon = Icons.account_balance_rounded;
        thirdChipColor = AppColors.primaryGreenLight;
        thirdChipTap = () => context.push('/wallets');
        break;
      case HomeScreenWidgetStat.monthlySavings:
        thirdChipLabel = 'Savings';
        thirdChipAmount = '${netSavings >= 0 ? '+' : ''}${settings.formatCompact(netSavings)}';
        thirdChipIcon = Icons.savings_rounded;
        thirdChipColor = AppColors.infoBlue;
        thirdChipTap = () => context.push('/analytics');
        break;
      case HomeScreenWidgetStat.budgetRemaining:
        thirdChipLabel = 'Budget Left';
        thirdChipAmount = settings.formatCompact(budgetRemaining);
        thirdChipIcon = Icons.pie_chart_rounded;
        thirdChipColor = Colors.amber;
        thirdChipTap = () => context.push('/budgets');
        break;
      case HomeScreenWidgetStat.debtsSummary:
        thirdChipLabel = 'Debts Due';
        final owedByMe = ref.watch(totalBorrowedProvider);
        thirdChipAmount = settings.formatCompact(owedByMe);
        thirdChipIcon = Icons.handshake_rounded;
        thirdChipColor = Colors.purpleAccent;
        thirdChipTap = () => context.push('/debts');
        break;
      case HomeScreenWidgetStat.forecastTrajectory:
        thirdChipLabel = 'Forecast';
        thirdChipAmount = settings.formatCompact(forecast.projectedMonthEndExpense);
        thirdChipIcon = Icons.trending_up_rounded;
        thirdChipColor = Colors.orangeAccent;
        thirdChipTap = () => context.push('/analytics');
        break;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF161922) : Colors.white,
            isDark ? const Color(0xFF0F1218) : const Color(0xFFF4F6FA),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? palette.primary.withValues(alpha: 0.28)
              : palette.primary.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: palette.primary.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Financial Cockpit Identifier & Accounts Link
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TOTAL NET POSITION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Semantics(
                      label: isPrivacy ? 'Reveal total balance' : 'Hide total balance',
                      button: true,
                      child: IconButton(
                        onPressed: _togglePeek,
                        icon: Icon(
                          isPrivacy ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        tooltip: isPrivacy ? 'Reveal Balance' : 'Mask Balance',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        splashRadius: 20,
                      ),
                    ),
                  ],
                ),
                // Accounts Counter & Direct Wallets Portal
                InkWell(
                  onTap: () => context.push('/wallets'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${liquidWallets.length} Accounts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 2. Hero Balance Row with Monthly Savings Delta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayBalanceStr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Monthly Net Delta Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: netSavings >= 0
                        ? AppColors.incomeGreen.withValues(alpha: isDark ? 0.16 : 0.10)
                        : AppColors.expenseRed.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: netSavings >= 0
                          ? AppColors.incomeGreen.withValues(alpha: 0.35)
                          : AppColors.expenseRed.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        netSavings >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 13,
                        color: netSavings >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        netSavings >= 0
                            ? '+${settings.formatCompact(netSavings)}'
                            : '-${settings.formatCompact(netSavings.abs())}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: netSavings >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Bento Cash Flow Pulse (Income | Expense | Today / Featured Stat)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _CockpitMetricChip(
                    label: 'Income',
                    amount: monthlyStats.totalIncome <= 0
                        ? settings.formatCompact(0.0)
                        : '+${settings.formatCompact(monthlyStats.totalIncome)}',
                    icon: Icons.arrow_downward_rounded,
                    accentColor: AppColors.incomeGreen,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CockpitMetricChip(
                    label: 'Expense',
                    amount: monthlyStats.totalExpense <= 0
                        ? settings.formatCompact(0.0)
                        : '-${settings.formatCompact(monthlyStats.totalExpense)}',
                    icon: Icons.arrow_upward_rounded,
                    accentColor: AppColors.expenseRed,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CockpitMetricChip(
                    label: thirdChipLabel,
                    amount: thirdChipAmount,
                    icon: thirdChipIcon,
                    accentColor: thirdChipColor,
                    isDark: isDark,
                    onTap: thirdChipTap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Safe-to-Spend Runway Footer Ribbon
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF13151D)
                    : const Color(0xFFECEFF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 15,
                    color: budgetRemaining <= 0 ? Colors.amber : palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      budgetRemaining > 0
                          ? 'Safe daily spend: ${settings.formatCurrency(safeDailySpend)}/day'
                          : (monthlyStats.totalIncome > 0
                              ? 'Net Savings Rate: ${(monthlyStats.netSavings / monthlyStats.totalIncome * 100).clamp(0, 100).toStringAsFixed(0)}% this month'
                              : 'Track all accounts in real time'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '${daysRemaining}d left',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CockpitMetricChip extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final VoidCallback? onTap;

  const _CockpitMetricChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1F2A) : const Color(0xFFF3F6FA),
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
                  Icon(icon, size: 12, color: accentColor),
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
              const SizedBox(height: 3),
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
        ),
      ),
    );
  }
}
