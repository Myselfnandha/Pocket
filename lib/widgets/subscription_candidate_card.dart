import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/app_providers.dart';
import '../services/subscription_detector_service.dart';
import '../theme/app_theme.dart';

class SubscriptionCandidateCard extends ConsumerWidget {
  final SubscriptionCandidate candidate;

  const SubscriptionCandidateCard({
    super.key,
    required this.candidate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletsProvider);
    final defaultWalletId = settings.defaultWalletId != null &&
            wallets.any((w) => w.id == settings.defaultWalletId)
        ? settings.defaultWalletId!
        : (wallets.isNotEmpty ? wallets.first.id : 'default');

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF7F5FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.deepPurpleAccent.withValues(alpha: 0.35)
              : Colors.deepPurpleAccent.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Subscription Detected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'REVIEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurpleAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.matchReason,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: isDark ? Colors.white38 : Colors.black38,
                  tooltip: 'Dismiss',
                  splashRadius: 16,
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .dismissSubscriptionCandidate(candidate.title);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    candidate.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${settings.formatCurrency(candidate.amount)} / mo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .dismissSubscriptionCandidate(candidate.title);
                    },
                    child: Text(
                      'Not Recurring',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text(
                      'Make Permanent',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final newRule = RecurringRuleModel(
                        id: const Uuid().v4(),
                        title: candidate.title,
                        amount: candidate.amount,
                        type: TransactionType.expense,
                        categoryId: candidate.categoryId,
                        walletId: defaultWalletId,
                        frequency: candidate.frequency,
                        dueDay: candidate.nextDueDate.day,
                        nextDueDate: candidate.nextDueDate,
                        createdAt: DateTime.now(),
                        isActive: true,
                        note: 'Auto-detected from bank transactions (${candidate.matchReason})',
                      );

                      ref.read(recurringRulesProvider.notifier).addRule(newRule);
                      ref
                          .read(settingsProvider.notifier)
                          .dismissSubscriptionCandidate(candidate.title);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${candidate.title} (${settings.formatCurrency(candidate.amount)}/mo) saved to Recurring Dues!',
                          ),
                          backgroundColor: AppColors.incomeGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
