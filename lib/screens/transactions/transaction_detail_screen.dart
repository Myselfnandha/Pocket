import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import 'edit_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTxs = ref.watch(transactionsProvider);
    final currentTx = allTxs.firstWhere(
      (t) => t.id == transaction.id,
      orElse: () => transaction,
    );
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final category = categories.firstWhere(
      (c) => c.id == currentTx.categoryId,
      orElse: () => const CategoryModel(
        id: 'other',
        name: 'Other',
        icon: '📦',
        colorValue: 0xFF2E7D32,
      ),
    );

    final wallet = wallets.firstWhere(
      (w) => w.id == currentTx.walletId,
      orElse: () => defaultWallets.first,
    );

    final isIncome = currentTx.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.incomeGreen : AppColors.expenseRed;
    final prefix = isIncome ? '+' : '-';
    final formattedAmount = NumberFormat('#,##0.00').format(currentTx.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreenLight),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => EditTransactionScreen(transaction: currentTx),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expenseRed),
            onPressed: () => _confirmDelete(context, ref, currentTx),
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
              currentTx.title,
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
                    value: DateFormat('d MMMM yyyy, h:mm a').format(currentTx.date),
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
                  if (currentTx.note != null && currentTx.note!.isNotEmpty) ...[
                    _buildDivider(isDark),
                    _buildDetailRow(
                      context,
                      icon: Icons.notes_rounded,
                      label: 'Note',
                      value: currentTx.note!,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dedicated Transfer & Payment Details Card (Sender, Receiver, UTR, Last 4)
            if (currentTx.senderName != null ||
                currentTx.receiverName != null ||
                currentTx.refId != null ||
                currentTx.counterpartyLast4 != null) ...[
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
                    if (currentTx.senderName != null && currentTx.senderName!.isNotEmpty) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Paid by (Sender)',
                        value: currentTx.senderName!,
                        isDark: isDark,
                      ),
                    ],
                    if (currentTx.receiverName != null && currentTx.receiverName!.isNotEmpty) ...[
                      if (currentTx.senderName != null && currentTx.senderName!.isNotEmpty) _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: Icons.person_pin_circle_outlined,
                        label: 'Paid to (Receiver)',
                        value: currentTx.receiverName!,
                        isDark: isDark,
                      ),
                    ],
                    if (currentTx.counterpartyLast4 != null && currentTx.counterpartyLast4!.isNotEmpty) ...[
                      _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: Icons.phone_android_rounded,
                        label: 'Account / Mobile',
                        value: '•••• ${currentTx.counterpartyLast4}',
                        isDark: isDark,
                      ),
                    ],
                    if (currentTx.refId != null && currentTx.refId!.isNotEmpty) ...[
                      _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: Icons.tag_rounded,
                        label: 'Ref / UTR ID',
                        value: currentTx.refId!,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Tags Section
            if (currentTx.tags.isNotEmpty) ...[
              Container(
                width: double.infinity,
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
                    const Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 18, color: AppColors.primaryGreenLight),
                        SizedBox(width: 8),
                        Text('Tags & Labels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: currentTx.tags.map((tag) {
                        return Chip(
                          label: Text('#$tag', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Attached Files & Documents Section
            if (currentTx.attachments.isNotEmpty ||
                (currentTx.receiptImagePath != null && currentTx.receiptImagePath!.isNotEmpty)) ...[
              Builder(
                builder: (context) {
                  final allFiles = {
                    if (currentTx.receiptImagePath != null && currentTx.receiptImagePath!.isNotEmpty)
                      currentTx.receiptImagePath!,
                    ...currentTx.attachments,
                  }.where((p) => File(p).existsSync()).toList();

                  if (allFiles.isEmpty) return const SizedBox.shrink();

                  return Container(
                    width: double.infinity,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.attach_file_rounded, size: 18, color: AppColors.primaryGreenLight),
                                SizedBox(width: 8),
                                Text('Attached Documents & Receipts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('${allFiles.length} files', style: const TextStyle(fontSize: 11, color: AppColors.primaryGreenLight)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...allFiles.map((filePath) {
                          final f = File(filePath);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => _showZoomableImage(context, f),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Image.file(
                                      f,
                                      width: double.infinity,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                          SizedBox(width: 4),
                                          Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 12),
            ],

            // Edit & Delete Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryGreenLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryGreenLight),
                    label: const Text('Edit Transaction', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => EditTransactionScreen(transaction: currentTx),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expenseRed.withValues(alpha: 0.15),
                      foregroundColor: AppColors.expenseRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () => _confirmDelete(context, ref, currentTx),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showZoomableImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete "${tx.title}"?'),
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
              ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
              Navigator.pop(ctx);
              context.pop();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFF1E1E1E),
                  content: Text('Deleted "${tx.title}"'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.primaryGreenLight,
                    onPressed: () {
                      ref.read(transactionsProvider.notifier).insertTransactionAt(0, tx);
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
