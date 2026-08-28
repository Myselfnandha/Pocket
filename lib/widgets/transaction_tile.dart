import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final settings = ref.watch(settingsProvider);

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.expenseRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: AppColors.expenseRed),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.expenseRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        onDelete?.call();
        ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${transaction.title}"'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColors.primaryGreenLight,
              onPressed: () {
                ref.read(transactionsProvider.notifier).addTransaction(
                      title: transaction.title,
                      amount: transaction.amount,
                      type: transaction.type,
                      categoryId: transaction.categoryId,
                      walletId: transaction.walletId,
                      date: transaction.date,
                      note: transaction.note,
                    );
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Category Icon Circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: isDark ? 0.2 : 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                        Text(
                          '${wallet.icon} ${wallet.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '$prefix${settings.currencySymbol}$formattedAmount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
