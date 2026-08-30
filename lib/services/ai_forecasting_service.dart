import 'dart:math';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/recurring_model.dart';

class DailySpendPoint {
  final int dayOfMonth;
  final double actualSpent;
  final double forecastedSpent;
  final double upperConfidenceBound;
  final double lowerConfidenceBound;
  final bool isProjected;

  const DailySpendPoint({
    required this.dayOfMonth,
    required this.actualSpent,
    required this.forecastedSpent,
    required this.upperConfidenceBound,
    required this.lowerConfidenceBound,
    required this.isProjected,
  });
}

class MonthSpendForecast {
  final double currentMonthSpendSoFar;
  final double currentDailyBurnRate;
  final double projectedMonthEndExpense;
  final double projectedMonthEndBalance;
  final double upperExpenseBound;
  final double lowerExpenseBound;
  final double upcomingRecurringBillsTotal;
  final int daysElapsed;
  final int daysRemainingInMonth;
  final int totalDaysInMonth;
  final List<DailySpendPoint> trajectory;
  final List<double> sparklineValues;

  const MonthSpendForecast({
    required this.currentMonthSpendSoFar,
    required this.currentDailyBurnRate,
    required this.projectedMonthEndExpense,
    required this.projectedMonthEndBalance,
    required this.upperExpenseBound,
    required this.lowerExpenseBound,
    required this.upcomingRecurringBillsTotal,
    required this.daysElapsed,
    required this.daysRemainingInMonth,
    required this.totalDaysInMonth,
    required this.trajectory,
    required this.sparklineValues,
  });
}

class AiForecastingService {
  /// Computes a statistical spend forecast with confidence bands and upcoming recurring obligations
  static MonthSpendForecast calculateForecast({
    required List<TransactionModel> transactions,
    required List<RecurringRuleModel> recurringRules,
    required double totalLiquidBalance,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final year = now.year;
    final month = now.month;
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;
    final daysElapsed = max(1, now.day);
    final daysRemaining = max(0, totalDaysInMonth - daysElapsed);

    // 1. Group current month's expenses by day
    final Map<int, double> dailyActualMap = {};
    double totalSpentThisMonth = 0.0;

    for (final tx in transactions) {
      if (tx.date.year == year &&
          tx.date.month == month &&
          tx.type == TransactionType.expense) {
        final d = tx.date.day;
        dailyActualMap[d] = (dailyActualMap[d] ?? 0.0) + tx.amount;
        totalSpentThisMonth += tx.amount;
      }
    }

    // 2. Compute mean daily burn rate & standard deviation of daily spending
    final List<double> dailySpendingList = [];
    for (int day = 1; day <= daysElapsed; day++) {
      dailySpendingList.add(dailyActualMap[day] ?? 0.0);
    }

    final double meanDailySpend = totalSpentThisMonth / daysElapsed;

    // Variance & StdDev
    double varianceSum = 0.0;
    for (final dailySpend in dailySpendingList) {
      varianceSum += pow(dailySpend - meanDailySpend, 2);
    }
    final double standardDeviation = dailySpendingList.length > 1
        ? sqrt(varianceSum / (dailySpendingList.length - 1))
        : meanDailySpend * 0.35; // Default 35% volatility for 1-day sample

    // 3. Aggregate upcoming recurring bills scheduled for the rest of this month
    double upcomingRecurringTotal = 0.0;
    for (final rule in recurringRules) {
      if (rule.isActive && !rule.isPaused && rule.type == TransactionType.expense) {
        if (rule.dueDay > daysElapsed && rule.dueDay <= totalDaysInMonth) {
          upcomingRecurringTotal += rule.amount;
        }
      }
    }

    // 4. Extrapolate projected month-end expense
    final double baselineDiscretionaryProjected = meanDailySpend * daysRemaining;
    final double projectedMonthEndExpense =
        totalSpentThisMonth + baselineDiscretionaryProjected + upcomingRecurringTotal;

    // Confidence interval: +/- 1.645 * standard error (approx 90% confidence envelope)
    final double confidenceMargin =
        (1.645 * standardDeviation * sqrt(max(1, daysRemaining))) + (baselineDiscretionaryProjected * 0.15);

    final double upperExpenseBound = projectedMonthEndExpense + confidenceMargin;
    final double lowerExpenseBound = max(totalSpentThisMonth, projectedMonthEndExpense - confidenceMargin);

    final double projectedMonthEndBalance = totalLiquidBalance - (baselineDiscretionaryProjected + upcomingRecurringTotal);

    // 5. Build cumulative trajectory series from Day 1 to TotalDaysInMonth
    final List<DailySpendPoint> trajectory = [];
    final List<double> sparklineValues = [];
    double cumulativeActual = 0.0;

    for (int day = 1; day <= totalDaysInMonth; day++) {
      if (day <= daysElapsed) {
        cumulativeActual += dailyActualMap[day] ?? 0.0;
        trajectory.add(
          DailySpendPoint(
            dayOfMonth: day,
            actualSpent: cumulativeActual,
            forecastedSpent: cumulativeActual,
            upperConfidenceBound: cumulativeActual,
            lowerConfidenceBound: cumulativeActual,
            isProjected: false,
          ),
        );
        sparklineValues.add(cumulativeActual);
      } else {
        // Projected days
        final daysIntoFuture = day - daysElapsed;
        final recurringAddedUpToDay = recurringRules
            .where((r) => r.isActive && !r.isPaused && r.type == TransactionType.expense && r.dueDay > daysElapsed && r.dueDay <= day)
            .fold(0.0, (sum, r) => sum + r.amount);

        final projectedCumulative =
            totalSpentThisMonth + (meanDailySpend * daysIntoFuture) + recurringAddedUpToDay;
        final progressiveMargin = (confidenceMargin * (daysIntoFuture / max(1, daysRemaining)));

        trajectory.add(
          DailySpendPoint(
            dayOfMonth: day,
            actualSpent: cumulativeActual,
            forecastedSpent: projectedCumulative,
            upperConfidenceBound: projectedCumulative + progressiveMargin,
            lowerConfidenceBound: max(cumulativeActual, projectedCumulative - progressiveMargin),
            isProjected: true,
          ),
        );
        sparklineValues.add(projectedCumulative);
      }
    }

    return MonthSpendForecast(
      currentMonthSpendSoFar: totalSpentThisMonth,
      currentDailyBurnRate: meanDailySpend,
      projectedMonthEndExpense: projectedMonthEndExpense,
      projectedMonthEndBalance: projectedMonthEndBalance,
      upperExpenseBound: upperExpenseBound,
      lowerExpenseBound: lowerExpenseBound,
      upcomingRecurringBillsTotal: upcomingRecurringTotal,
      daysElapsed: daysElapsed,
      daysRemainingInMonth: daysRemaining,
      totalDaysInMonth: totalDaysInMonth,
      trajectory: trajectory,
      sparklineValues: sparklineValues,
    );
  }
}
