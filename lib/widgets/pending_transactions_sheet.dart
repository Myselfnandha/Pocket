import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pending_transaction_model.dart';
import '../providers/pending_transactions_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/wallets_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/currency_formatter.dart';
import 'top_capsule_toast.dart';

Future<void> showPendingTransactionsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const PendingTransactionsSheet(),
  );
}

class PendingTransactionsSheet extends ConsumerStatefulWidget {
  const PendingTransactionsSheet({super.key});

  @override
  ConsumerState<PendingTransactionsSheet> createState() => _PendingTransactionsSheetState();
}

class _PendingTransactionsSheetState extends ConsumerState<PendingTransactionsSheet> {
  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingTransactionsProvider);
    final palette = ref.watch(activePaletteProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191920) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: palette.primary.withValues(alpha: 0.35), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        'Review Detected Payments',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${pending.length} pending unconfirmed transactions',
                        style: TextStyle(
                          fontSize: 12,
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
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primary,
                      backgroundColor: palette.primary.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 24),

          // List of Pending Items
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 54, color: palette.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('All Caught Up!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'No unconfirmed payments. New transactions from GPay, PhonePe, or Paytm will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                shrinkWrap: true,
                itemCount: pending.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final item = pending[index];
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
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(item.amount, currencySymbol: currency),
                              style: TextStyle(
                                fontSize: 17,
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
                        Row(
                          children: [
                            // Category Selector Pill
                            InkWell(
                              onTap: () => _pickCategory(context, item, categories),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            const SizedBox(width: 8),

                            // Wallet Selector Pill
                            InkWell(
                              onTap: () => _pickWallet(context, item, wallets),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          ],
                        ),
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
    );
  }

  void _pickCategory(BuildContext context, PendingTransactionModel item, List dynamicCats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  void _pickWallet(BuildContext context, PendingTransactionModel item, List dynamicWallets) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}
