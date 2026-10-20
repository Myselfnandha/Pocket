import '../models/transaction_model.dart';
import '../models/recurring_model.dart';
import '../models/settings_model.dart';

class SubscriptionCandidate {
  final String title;
  final double amount;
  final String categoryId;
  final RecurringFrequency frequency;
  final DateTime nextDueDate;
  final int occurrences;
  final String matchReason;

  const SubscriptionCandidate({
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.nextDueDate,
    required this.occurrences,
    required this.matchReason,
  });
}

class SubscriptionDetectorService {
  static const List<String> _knownKeywords = [
    'netflix',
    'spotify',
    'prime',
    'disney',
    'hotstar',
    'youtube',
    'apple',
    'chatgpt',
    'openai',
    'claude',
    'anthropic',
    'github',
    'canva',
    'notion',
    'google one',
    'icloud',
    'adobe',
    'office 365',
    'microsoft 365',
    'dropbox',
    'airtel',
    'jio',
    'cult.fit',
    'gym',
    'broadband',
    'wifi',
    'patreon',
    'substack',
  ];

  static List<SubscriptionCandidate> detectCandidates({
    required List<TransactionModel> transactions,
    required List<RecurringRuleModel> existingRules,
    required UserSettingsModel settings,
  }) {
    if (transactions.isEmpty) return const [];

    final dismissed = settings.dismissedSubscriptionCandidates.map((e) => e.toLowerCase().trim()).toSet();
    final existingRuleTitles = existingRules.map((r) => r.title.toLowerCase().trim()).toSet();

    final candidates = <String, SubscriptionCandidate>{};

    // Filter to expenses only
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // 1. Keyword-based Detection (Immediate 1-occurrence detection for known streaming/services)
    for (final tx in expenses) {
      final cleanTitle = tx.title.trim();
      final lowerTitle = cleanTitle.toLowerCase();

      if (dismissed.contains(lowerTitle)) continue;
      if (existingRuleTitles.any((et) => et.contains(lowerTitle) || lowerTitle.contains(et))) continue;

      final matchedKeyword = _knownKeywords.firstWhere(
        (kw) => lowerTitle.contains(kw),
        orElse: () => '',
      );

      if (matchedKeyword.isNotEmpty && !candidates.containsKey(lowerTitle)) {
        // Calculate estimated next due date (30 days from last transaction date)
        final nextDue = tx.date.add(const Duration(days: 30));
        candidates[lowerTitle] = SubscriptionCandidate(
          title: cleanTitle,
          amount: tx.amount,
          categoryId: tx.categoryId,
          frequency: RecurringFrequency.monthly,
          nextDueDate: nextDue.isBefore(DateTime.now())
              ? DateTime.now().add(const Duration(days: 7))
              : nextDue,
          occurrences: 1,
          matchReason: 'Recognized subscription (${matchedKeyword.toUpperCase()})',
        );
      }
    }

    // 2. Repetition-based Detection: Same Title + Same Amount across multiple dates (20 - 35 days apart)
    final groupedByTitle = <String, List<TransactionModel>>{};
    for (final tx in expenses) {
      final lower = tx.title.toLowerCase().trim();
      if (dismissed.contains(lower)) continue;
      if (existingRuleTitles.any((et) => et.contains(lower) || lower.contains(et))) continue;
      groupedByTitle.putIfAbsent(lower, () => []).add(tx);
    }

    for (final entry in groupedByTitle.entries) {
      final txList = entry.value;
      if (txList.length < 2) continue;
      if (candidates.containsKey(entry.key)) continue;

      // Check if amounts match
      final firstAmount = txList.first.amount;
      final matchingAmounts = txList.where((t) => (t.amount - firstAmount).abs() < 0.05).toList();

      if (matchingAmounts.length >= 2) {
        // Check time intervals between consecutive transactions
        matchingAmounts.sort((a, b) => a.date.compareTo(b.date));
        bool hasMonthlyCadence = false;

        for (int i = 0; i < matchingAmounts.length - 1; i++) {
          final diffDays = matchingAmounts[i + 1].date.difference(matchingAmounts[i].date).inDays;
          if (diffDays >= 20 && diffDays <= 35) {
            hasMonthlyCadence = true;
            break;
          }
        }

        if (hasMonthlyCadence) {
          final lastTx = matchingAmounts.last;
          final nextDue = lastTx.date.add(const Duration(days: 30));
          candidates[entry.key] = SubscriptionCandidate(
            title: lastTx.title,
            amount: lastTx.amount,
            categoryId: lastTx.categoryId,
            frequency: RecurringFrequency.monthly,
            nextDueDate: nextDue.isBefore(DateTime.now())
                ? DateTime.now().add(const Duration(days: 5))
                : nextDue,
            occurrences: matchingAmounts.length,
            matchReason: 'Repeated monthly expense (${matchingAmounts.length} cycles)',
          );
        }
      }
    }

    return candidates.values.toList();
  }
}
