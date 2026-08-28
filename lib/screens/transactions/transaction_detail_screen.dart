import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final category = categories.firstWhere(
      (c) => c.id == transaction.categoryId,
      orElse: () => const CategoryModel(
        id: 'other',
        name: 'Other',
        icon: '📦',
        colorValue: 0xFF2E7D32,
      ),
    );

    final wallet = wallets.firstWhere(
      (w) => w.id == transaction.walletId,
      orElse: () => defaultWallets.first,
    );

    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.incomeGreen : AppColors.expenseRed;
    final prefix = isIncome ? '+' : '-';
    final formattedAmount = NumberFormat('#,##0.00').format(transaction.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expenseRed),
            onPressed: () => _confirmDelete(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Hero Category Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: isDark ? 0.25 : 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              transaction.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Category Subtitle
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreenLight,
              ),
            ),
            const SizedBox(height: 14),

            // Big Amount Text
            Text(
              '$prefix${settings.currencySymbol}$formattedAmount',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 28),

            // Details Card
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
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: DateFormat('d MMMM yyyy, h:mm a').format(transaction.date),
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildDetailRow(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    value: '${wallet.icon} ${wallet.name}',
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildDetailRow(
                    context,
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: '${category.icon} ${category.name}',
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildDetailRow(
                    context,
                    icon: Icons.swap_horiz_rounded,
                    label: 'Type',
                    value: isIncome ? 'Income' : 'Expense',
                    valueColor: amountColor,
                    isDark: isDark,
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    _buildDivider(isDark),
                    _buildDetailRow(
                      context,
                      icon: Icons.notes_rounded,
                      label: 'Note',
                      value: transaction.note!,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expenseRed,
                      side: const BorderSide(color: AppColors.expenseRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
