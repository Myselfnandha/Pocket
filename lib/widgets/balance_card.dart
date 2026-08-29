import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final settings = ref.watch(settingsProvider);

    final currencyFormat = NumberFormat('#,##0.00');
    final compactFormat = NumberFormat.compact();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B5E20), // Dark green
            Color(0xFF2E7D32), // Forest green
            Color(0xFF388E3C), // Medium green
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  settings.currencyCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Big Balance Text
          Text(
            '${settings.currencySymbol}${currencyFormat.format(totalBalance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // 3 Pro Columns Grid: Income | Expense | Today (Enlarged & Professional)
          Row(
            children: [
              // Income
              Expanded(
                child: _MetricPill(
                  label: 'Income',
                  amount: '+${settings.currencySymbol}${compactFormat.format(monthlyStats.totalIncome)}',
                  icon: Icons.call_received_rounded,
                  iconColor: const Color(0xFFA5D6A7),
                ),
              ),
              const SizedBox(width: 8),

              // Expense
              Expanded(
                child: _MetricPill(
                  label: 'Expense',
                  amount: '-${settings.currencySymbol}${compactFormat.format(monthlyStats.totalExpense)}',
                  icon: Icons.call_made_rounded,
                  iconColor: const Color(0xFFFFAB91),
                ),
              ),
              const SizedBox(width: 8),

              // Today
              Expanded(
                child: _MetricPill(
                  label: 'Today',
                  amount: '${settings.currencySymbol}${compactFormat.format(monthlyStats.todayExpense)}',
                  icon: Icons.today_rounded,
                  iconColor: AppColors.accentOrangeLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const _MetricPill({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
