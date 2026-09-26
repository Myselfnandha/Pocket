import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pending_transaction_model.dart';
import '../providers/pending_transactions_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/wallets_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/currency_formatter.dart';
import 'top_capsule_toast.dart';

Future<void> showPendingTransactionsSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => const PendingTransactionsSheet(),
  );
}

class PendingTransactionsSheet extends ConsumerStatefulWidget {
  const PendingTransactionsSheet({super.key});

  @override
  ConsumerState<PendingTransactionsSheet> createState() => _PendingTransactionsSheetState();
}

class _PendingTransactionsSheetState extends ConsumerState<PendingTransactionsSheet> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingTransactionsProvider);
    final palette = ref.watch(activePaletteProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF191920) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: palette.primary.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detected Payments',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${pending.length} unconfirmed transactions',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pending.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: () async {
                        final count = await ref.read(pendingTransactionsProvider.notifier).approveAll();
                        if (context.mounted) {
                          Navigator.pop(context);
                          TopCapsuleToast.show(
                            context,
                            title: 'Successfully saved $count transactions',
                            icon: const Icon(Icons.done_all_rounded, color: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Approve All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.primary,
                        backgroundColor: palette.primary.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),

            // Content Area
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 54, color: palette.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('All Caught Up!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'No unconfirmed payments. New transactions from GPay, PhonePe, or SMS will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final item = pending[index];
                    final isExpanded = _expandedIds.contains(item.id);
                    final currentCat = categories.firstWhere(
                      (c) => c.id == item.suggestedCategoryId,
                      orElse: () => categories.first,
                    );
                    final currentWallet = wallets.firstWhere(
                      (w) => w.id == item.suggestedWalletId,
                      orElse: () => wallets.first,
                    );

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22222B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Merchant & Amount
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  item.merchant,
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(item.amount, currencySymbol: currency),
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: item.isIncome ? Colors.greenAccent : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ],
                          ),

                          if (item.refId != null && item.refId!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'UPI Ref: ${item.refId}',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Interactive Category & Wallet Selector Pills
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Category Selector Pill
                              InkWell(
                                onTap: () => _pickCategory(context, item, categories),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(currentCat.icon, style: const TextStyle(fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentCat.name,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),

                              // Wallet Selector Pill
                              InkWell(
                                onTap: () => _pickWallet(context, item, wallets),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(currentWallet.icon, style: const TextStyle(fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentWallet.name,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),

                              // More Details Toggle Button
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedIds.remove(item.id);
                                    } else {
                                      _expandedIds.add(item.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isExpanded ? 'Less' : 'Details',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: palette.primary,
                                        ),
                                      ),
                                      Icon(
                                        isExpanded ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                        size: 16,
                                        color: palette.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Expandable Details Section
                          if (isExpanded) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF17171F) : const Color(0xFFECEFF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Timestamp: ${DateFormat('dd MMM yyyy, hh:mm a').format(item.date)}',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: palette.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.detectionSource.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.rawPayload != null && item.rawPayload!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Raw SMS / Notification:',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.rawPayload!.trim(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Bottom row: Source app tag (left) & Actions (right)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.detectionSource == 'screenshot'
                                          ? Icons.camera_alt_outlined
                                          : (item.detectionSource == 'screen_reader'
                                              ? Icons.visibility_outlined
                                              : Icons.notifications_active_outlined),
                                      size: 13,
                                      color: palette.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.appSource,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: palette.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Dismiss Button
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: Colors.grey,
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Dismiss',
                                onPressed: () {
                                  ref.read(pendingTransactionsProvider.notifier).dismiss(item.id);
                                },
                              ),
                              const SizedBox(width: 4),
                              // Save Button
                              FilledButton.icon(
                                onPressed: () async {
                                  await ref.read(pendingTransactionsProvider.notifier).approve(
                                        item.id,
                                        categoryId: item.suggestedCategoryId,
                                        walletId: item.suggestedWalletId,
                                      );
                                  if (context.mounted) {
                                    TopCapsuleToast.show(
                                      context,
                                      title: 'Saved ${CurrencyFormatter.format(item.amount, currencySymbol: currency)} to ${item.merchant}',
                                      icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _pickCategory(BuildContext context, PendingTransactionModel item, List dynamicCats) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dynamicCats.length,
            itemBuilder: (c, i) {
              final cat = dynamicCats[i];
              return ListTile(
                leading: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  ref.read(pendingTransactionsProvider.notifier).dismiss(item.id);
                  ref.read(pendingTransactionsProvider.notifier).addPending(
                        item.copyWith(suggestedCategoryId: cat.id),
                      );
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _pickWallet(BuildContext context, PendingTransactionModel item, List dynamicWallets) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dynamicWallets.length,
            itemBuilder: (c, i) {
              final w = dynamicWallets[i];
              return ListTile(
                leading: Text(w.icon, style: const TextStyle(fontSize: 22)),
                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  ref.read(pendingTransactionsProvider.notifier).dismiss(item.id);
                  ref.read(pendingTransactionsProvider.notifier).addPending(
                        item.copyWith(suggestedWalletId: w.id),
                      );
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
