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
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showPendingTransactionsSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Glowing Pulse Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: palette.primary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: palette.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            count == 1 ? '1 Detected Payment' : '$count Detected Payments',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              firstItem.appSource,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${firstItem.merchant} • ${CurrencyFormatter.format(firstItem.amount, currencySymbol: currency)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick 1-tap Approve
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      color: palette.primary,
                      iconSize: 26,
                      tooltip: 'Approve',
                      onPressed: () async {
                        await ref.read(pendingTransactionsProvider.notifier).approve(firstItem.id);
                        if (context.mounted) {
                          TopCapsuleToast.show(
                            context,
                            title: 'Saved ${CurrencyFormatter.format(firstItem.amount, currencySymbol: currency)} to ${firstItem.merchant}',
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                          );
                        }
                      },
                    ),
                    // Review Chevron
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
