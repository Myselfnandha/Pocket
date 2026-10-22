import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pending_transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/currency_formatter.dart';
import 'pending_transactions_sheet.dart';
import 'top_capsule_toast.dart';

class PendingTransactionsCapsule extends ConsumerWidget {
  const PendingTransactionsCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTransactionsProvider);
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = ref.watch(activePaletteProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstItem = pending.first;
    final count = pending.length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => showPendingTransactionsSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Small Glowing Indicator Dot / Icon
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.primary.withValues(alpha: 0.18),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: palette.primary,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pill Text: Compact Merchant • Amount • Source
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          count > 1 ? '$count Detected' : firstItem.appSource,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${firstItem.merchant} • ${CurrencyFormatter.format(firstItem.amount, currencySymbol: currency)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Compact Quick-Approve Button
                InkWell(
                  onTap: () async {
                    await ref.read(pendingTransactionsProvider.notifier).approve(firstItem.id);
                    if (context.mounted) {
                      TopCapsuleToast.show(
                        context,
                        title: 'Saved ${CurrencyFormatter.format(firstItem.amount, currencySymbol: currency)} to ${firstItem.merchant}',
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: palette.primary,
                      size: 20,
                    ),
                  ),
                ),

                // Tiny Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
