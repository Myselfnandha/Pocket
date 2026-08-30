import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../services/ai_forecasting_service.dart';
import '../services/financial_health_service.dart';
import 'transactions_provider.dart';
import 'wallets_provider.dart';
import 'goals_provider.dart';
import 'debts_provider.dart';
import 'budgets_provider.dart';
import 'recurring_rules_provider.dart';

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

// --- Net Worth Tracker (Wallets + Goals + Lent − Borrowed) ---

class NetWorthSummary {
  final double totalNetWorth;
  final double liquidAssets;
  final double goalReserves;
  final double lentReceivables;
  final double borrowedLiabilities;
  final double totalAssets;

  const NetWorthSummary({
    required this.totalNetWorth,
    required this.liquidAssets,
    required this.goalReserves,
    required this.lentReceivables,
    required this.borrowedLiabilities,
    required this.totalAssets,
  });
}

final netWorthSummaryProvider = Provider<NetWorthSummary>((ref) {
  final liquid = ref.watch(totalBalanceProvider);
  final goals = ref.watch(totalSavedInGoalsProvider);
  final lent = ref.watch(totalLentProvider);
  final borrowed = ref.watch(totalBorrowedProvider);

  final totalAssets = liquid + goals + lent;
  final netWorth = totalAssets - borrowed;

  return NetWorthSummary(
    totalNetWorth: netWorth,
    liquidAssets: liquid,
    goalReserves: goals,
    lentReceivables: lent,
    borrowedLiabilities: borrowed,
    totalAssets: totalAssets,
  );
});

// --- Spending Comparison (This Month vs. Last Month) ---

class CategoryComparison {
  final String categoryId;
  final double thisMonthSpent;
  final double lastMonthSpent;
  final double diffAmount;
  final double percentChange;

  const CategoryComparison({
    required this.categoryId,
    required this.thisMonthSpent,
    required this.lastMonthSpent,
    required this.diffAmount,
    required this.percentChange,
  });
}

class MonthOverMonthSpendingComparison {
  final double thisMonthTotalExpense;
  final double lastMonthTotalExpense;
  final double differenceAmount;
  final double percentageChange;
  final bool isSpendingHigher;
  final List<CategoryComparison> categoryComparisons;

  const MonthOverMonthSpendingComparison({
    required this.thisMonthTotalExpense,
    required this.lastMonthTotalExpense,
    required this.differenceAmount,
    required this.percentageChange,
    required this.isSpendingHigher,
    required this.categoryComparisons,
  });
}

final spendingComparisonProvider = Provider<MonthOverMonthSpendingComparison>((ref) {
  final txs = ref.watch(transactionsProvider);
  final now = DateTime.now();
  final lastMonthDate = DateTime(now.year, now.month - 1, 1);

  double thisMonthTotal = 0.0;
  double lastMonthTotal = 0.0;
  final Map<String, double> thisMonthCats = {};
  final Map<String, double> lastMonthCats = {};

  for (final tx in txs) {
    if (tx.type == TransactionType.expense) {
      if (tx.date.year == now.year && tx.date.month == now.month) {
        thisMonthTotal += tx.amount;
        thisMonthCats[tx.categoryId] = (thisMonthCats[tx.categoryId] ?? 0.0) + tx.amount;
      } else if (tx.date.year == lastMonthDate.year && tx.date.month == lastMonthDate.month) {
        lastMonthTotal += tx.amount;
        lastMonthCats[tx.categoryId] = (lastMonthCats[tx.categoryId] ?? 0.0) + tx.amount;
      }
    }
  }

  final diff = thisMonthTotal - lastMonthTotal;
  final pct = lastMonthTotal > 0 ? (diff / lastMonthTotal * 100) : 0.0;

  final allCatIds = {...thisMonthCats.keys, ...lastMonthCats.keys};
  final List<CategoryComparison> catList = [];

  for (final catId in allCatIds) {
    final tSpent = thisMonthCats[catId] ?? 0.0;
    final lSpent = lastMonthCats[catId] ?? 0.0;
    final cDiff = tSpent - lSpent;
    final cPct = lSpent > 0 ? (cDiff / lSpent * 100) : 0.0;
    catList.add(CategoryComparison(
      categoryId: catId,
      thisMonthSpent: tSpent,
      lastMonthSpent: lSpent,
      diffAmount: cDiff,
      percentChange: cPct,
    ));
  }

  catList.sort((a, b) => b.thisMonthSpent.compareTo(a.thisMonthSpent));

  return MonthOverMonthSpendingComparison(
    thisMonthTotalExpense: thisMonthTotal,
    lastMonthTotalExpense: lastMonthTotal,
    differenceAmount: diff,
    percentageChange: pct,
    isSpendingHigher: diff > 0,
    categoryComparisons: catList,
  );
});

/// Computes on-device statistical spend forecast with confidence bands and upcoming recurring obligations
final monthSpendForecastProvider = Provider<MonthSpendForecast>((ref) {
  final txs = ref.watch(transactionsProvider);
  final rules = ref.watch(recurringRulesProvider);
  final liquidBalance = ref.watch(totalBalanceProvider);

  return AiForecastingService.calculateForecast(
    transactions: txs,
    recurringRules: rules,
    totalLiquidBalance: liquidBalance,
  );
});

/// Computes composite 0-1000 Financial Health Score report
final financialHealthReportProvider = Provider<FinancialHealthReport>((ref) {
  final stats = ref.watch(monthlyStatsProvider);
  final budgets = ref.watch(categoryBudgetsProvider);
  final catSpending = ref.watch(currentMonthCategorySpendingProvider);
  final debts = ref.watch(debtsProvider);
  final wallets = ref.watch(walletsWithBalancesProvider);
  final goals = ref.watch(goalsProvider);

  return FinancialHealthService.calculateScore(
    totalIncome: stats.totalIncome,
    totalExpense: stats.totalExpense,
    budgets: budgets,
    currentMonthCategorySpending: catSpending,
    debts: debts,
    wallets: wallets,
    goals: goals,
  );
});
