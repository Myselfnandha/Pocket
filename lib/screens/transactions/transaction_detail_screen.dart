import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_capsule_toast.dart';
import '../../services/system_contact_service.dart';
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
    final showSender = currentTx.senderName != null &&
        currentTx.senderName!.isNotEmpty &&
        !_isGenericOrBankIdentifier(currentTx.senderName, currentTx.senderBank, currentTx.appSource);
    final showReceiver = currentTx.receiverName != null &&
        currentTx.receiverName!.isNotEmpty &&
        !_isGenericOrBankIdentifier(currentTx.receiverName, currentTx.senderBank, currentTx.appSource);

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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
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

            // Dedicated Transfer & Payment Details Card (Bank Account, Sender, Receiver, UTR, Last 4, Source, Contact)
            if (currentTx.senderName != null ||
                currentTx.receiverName != null ||
                currentTx.refId != null ||
                currentTx.counterpartyLast4 != null ||
                currentTx.senderBank != null ||
                currentTx.linkedContactName != null ||
                currentTx.appSource != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sender Bank & Masked Account
                    if (currentTx.senderBank != null ||
                        (currentTx.counterpartyLast4 != null && currentTx.counterpartyLast4!.isNotEmpty)) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.account_balance_rounded,
                        label: 'Bank & Account',
                        value: [
                          if (currentTx.senderBank != null && currentTx.senderBank!.isNotEmpty) currentTx.senderBank!,
                          if (currentTx.counterpartyLast4 != null && currentTx.counterpartyLast4!.isNotEmpty) '•••• ${currentTx.counterpartyLast4}',
                        ].join('  •  '),
                        isDark: isDark,
                      ),
                    ],
                    if (showSender) ...[
                      if (currentTx.senderBank != null || (currentTx.counterpartyLast4 != null && currentTx.counterpartyLast4!.isNotEmpty)) _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Paid by (Sender)',
                        value: currentTx.senderName!,
                        isDark: isDark,
                      ),
                    ],
                    if (showReceiver) ...[
                      if (showSender || currentTx.senderBank != null || (currentTx.counterpartyLast4 != null && currentTx.counterpartyLast4!.isNotEmpty)) _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: Icons.person_pin_circle_outlined,
                        label: 'Paid to (Receiver)',
                        value: currentTx.receiverName!,
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
                    if (currentTx.appSource != null && currentTx.appSource!.isNotEmpty) ...[
                      _buildDivider(isDark),
                      _buildDetailRow(
                        context,
                        icon: currentTx.appSource!.toUpperCase().contains('SMS')
                            ? Icons.sms_rounded
                            : Icons.hub_rounded,
                        label: 'Source / Channel',
                        value: currentTx.appSource!,
                        isDark: isDark,
                      ),
                    ],
                    _buildDivider(isDark),
                    // Assigned Contact / Account Section
                    if (currentTx.linkedContactName != null && currentTx.linkedContactName!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19221C) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryGreenLight.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryGreenLight.withValues(alpha: 0.2),
                                child: Text(
                                  currentTx.linkedContactName![0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreenLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentTx.linkedContactName!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Linked Contact',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryGreenLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (currentTx.linkedContactPhone != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        currentTx.linkedContactPhone!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Change Contact / Account',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _showAssignModal(context, ref, currentTx, isDark),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                tooltip: 'Unlink Contact',
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final unlinkedTx = currentTx.copyWith(
                                    linkedContactName: null,
                                    linkedContactPhone: null,
                                  );
                                  await ref.read(transactionsProvider.notifier).updateTransaction(unlinkedTx);
                                  if (context.mounted) {
                                    TopCapsuleToast.showBottom(context, message: 'Contact unlinked');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text(
                              'Assign to Contact or Account',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreenLight,
                              side: BorderSide(color: AppColors.primaryGreenLight.withValues(alpha: 0.35)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _showAssignModal(context, ref, currentTx, isDark),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // If none of the counterparty fields are present, provide a clean 1-tap card to link contact or account
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 17,
                        color: AppColors.primaryGreenLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assign Contact / Account',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Link this transaction to a person or bank',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAssignModal(context, ref, currentTx, isDark),
                      child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Auto-Import & Raw Message Verification Card
            if (currentTx.rawPayload != null && currentTx.rawPayload!.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 18, color: AppColors.primaryGreenLight),
                            SizedBox(width: 8),
                            Text('Source Message & Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy source message',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: currentTx.rawPayload!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Source message copied to clipboard'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141419) : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        currentTx.rawPayload!.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                    ),
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 17,
              color: AppColors.primaryGreenLight,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
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
              final settings = ref.read(settingsProvider);
              ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
              Navigator.pop(ctx);
              TopCapsuleToast.showBottom(
                context,
                message: 'Deleted "${tx.title}" (${settings.formatCurrency(tx.amount)})',
                actionLabel: 'Undo',
                onAction: () {
                  ref.read(transactionsProvider.notifier).insertTransactionAt(0, tx);
                },
              );
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAssignModal(BuildContext context, WidgetRef ref, TransactionModel tx, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        final wallets = ref.watch(walletsWithBalancesProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_ind_rounded, color: AppColors.primaryGreenLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assign Contact or Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Remember party details for this and future transactions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Option 1: Pick from Device Contacts
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.contacts_rounded, color: AppColors.infoBlue, size: 20),
                  ),
                  title: const Text('Pick from Device Contacts', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Native contact picker (zero permissions)', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () async {
                    Navigator.pop(bottomSheetCtx);
                    final contact = await SystemContactService.pickContact();
                    if (contact != null) {
                      final updatedTx = tx.copyWith(
                        linkedContactName: contact.name,
                        linkedContactPhone: contact.phone,
                      );
                      await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
                      if (context.mounted) {
                        TopCapsuleToast.showBottom(context, message: 'Assigned to ${contact.name}');
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Option 2: Assign to Wallet / Bank Account
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 20),
                  ),
                  title: const Text('Assign to Bank Account / Wallet', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Current: ${wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => wallets.first).name}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _showWalletSelectorModal(context, ref, tx, isDark);
                  },
                ),
                const SizedBox(height: 12),
                // Option 3: Manual Name/Phone Entry
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.purple, size: 20),
                  ),
                  title: const Text('Enter Details Manually', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Type custom counterparty name or bank', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _showManualAssignDialog(context, ref, tx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWalletSelectorModal(BuildContext context, WidgetRef ref, TransactionModel tx, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final wallets = ref.watch(walletsWithBalancesProvider);
        final settings = ref.watch(settingsProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Wallet / Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final w = wallets[index];
                      final isSelected = w.id == tx.walletId;
                      return ListTile(
                        selected: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white10 : Colors.black12),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Color(w.colorValue).withValues(alpha: 0.2),
                          child: Text(w.icon, style: const TextStyle(fontSize: 18)),
                        ),
                        title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: w.accountNumber != null ? Text('A/C •••• ${w.accountNumber}') : null,
                        trailing: Text(
                          settings.formatCurrency(w.currentBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final updatedTx = tx.copyWith(walletId: w.id);
                          await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
                          if (context.mounted) {
                            TopCapsuleToast.showBottom(context, message: 'Assigned to ${w.name}');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualAssignDialog(BuildContext context, WidgetRef ref, TransactionModel tx) {
    final suggestedName = tx.linkedContactName ??
        (!_isGenericOrBankIdentifier(tx.senderName, tx.senderBank, tx.appSource) ? tx.senderName : null) ??
        (!_isGenericOrBankIdentifier(tx.receiverName, tx.senderBank, tx.appSource) ? tx.receiverName : null) ??
        '';
    final nameCtrl = TextEditingController(text: suggestedName);
    final phoneCtrl = TextEditingController(text: tx.linkedContactPhone ?? '');
    final bankCtrl = TextEditingController(text: tx.senderBank ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Assign Counterparty Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact / Person Name',
                  prefixIcon: Icon(Icons.person_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  prefixIcon: Icon(Icons.phone_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Name (Optional)',
                  prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                  hintText: 'e.g. State Bank of India, HDFC',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              final newBank = bankCtrl.text.trim();

              final updatedTx = tx.copyWith(
                linkedContactName: newName.isNotEmpty ? newName : null,
                linkedContactPhone: newPhone.isNotEmpty ? newPhone : null,
                senderBank: newBank.isNotEmpty ? newBank : tx.senderBank,
              );
              await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                TopCapsuleToast.showBottom(
                  context,
                  message: newName.isNotEmpty ? 'Assigned to $newName' : 'Details saved',
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _isGenericOrBankIdentifier(String? name, String? senderBank, String? appSource) {
    if (name == null || name.trim().isEmpty) return true;
    final clean = name.trim().toLowerCase();
    if (clean == 'payment' || clean == 'upi payment' || clean == 'payment received' || clean == 'salary' || clean == 'refund' || clean == 'cashback') {
      return true;
    }
    if (senderBank != null && (clean == senderBank.trim().toLowerCase() || senderBank.toLowerCase().contains(clean))) {
      return true;
    }
    if (appSource != null && appSource.toLowerCase().contains(clean)) {
      return true;
    }
    const bankCodes = {
      'indusb', 'indbnk', 'hdfcbk', 'sbiinb', 'icicib', 'axisbk', 'kotakb',
      'pnbsms', 'bobsms', 'canbnk', 'unionb', 'idfcfb', 'fedbnk', 'rblbnk', 'yesbnk'
    };
    return bankCodes.contains(clean);
  }
}
