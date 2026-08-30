import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import 'transactions_provider.dart';
import 'wallets_provider.dart';

final totalBalanceProvider = Provider<double>((ref) {
  final wallets = ref.watch(walletsWithBalancesProvider);
  return wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
});

class MonthlyStats {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate;
  final double todayExpense;

  const MonthlyStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.todayExpense,
  });
}

final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();

  double income = 0;
  double expense = 0;
  double todayExp = 0;

  for (final tx in txs) {
    if (tx.date.year == now.year && tx.date.month == now.month) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
        if (tx.date.day == now.day) {
          todayExp += tx.amount;
        }
      }
    }
  }

  final net = income - expense;
  final rate = income > 0 ? (net / income * 100).clamp(0.0, 100.0) : 0.0;

  return MonthlyStats(
    totalIncome: income,
    totalExpense: expense,
    netSavings: net,
    savingsRate: rate,
    todayExpense: todayExp,
  );
});
