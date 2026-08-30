import 'dart:math';
import '../models/budget_model.dart';
import '../models/debt_model.dart';
import '../models/goal_model.dart';
import '../models/wallet_model.dart';

class HealthPillarScore {
  final String name;
  final int score;
  final int maxScore;
  final String status;
  final String detail;

  const HealthPillarScore({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.detail,
  });

  double get ratio => (score / maxScore).clamp(0.0, 1.0);
}

class FinancialHealthReport {
  final int totalScore; // 0 to 1000
  final String grade; // A+, A, B, C, D
  final String statusTitle;
  final String statusSummary;
  final List<HealthPillarScore> pillars;
  final List<String> actionableTips;

  const FinancialHealthReport({
    required this.totalScore,
    required this.grade,
    required this.statusTitle,
    required this.statusSummary,
    required this.pillars,
    required this.actionableTips,
  });
}

class FinancialHealthService {
  /// Computes a comprehensive 0-1000 Financial Health Score
  static FinancialHealthReport calculateScore({
    required double totalIncome,
    required double totalExpense,
    required List<CategoryBudgetModel> budgets,
    required Map<String, double> currentMonthCategorySpending,
    required List<DebtModel> debts,
    required List<WalletModel> wallets,
    required List<GoalModel> goals,
    String currencySymbol = '₹',
  }) {
    final double netSavings = totalIncome - totalExpense;
    final double savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;
    final double liquidBalance = wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
    final double totalBorrowed = debts
        .where((d) => d.type == DebtType.borrowed && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);

    // 1. Pillar 1: Savings Rate (0 - 300 pts)
    int savingsScore = 0;
    String savingsStatus = 'Low';
    if (savingsRate >= 35) {
      savingsScore = 300;
      savingsStatus = 'Exceptional (35%+)';
    } else if (savingsRate >= 20) {
      savingsScore = (200 + ((savingsRate - 20) / 15 * 100)).round();
      savingsStatus = 'Healthy (20-35%)';
    } else if (savingsRate >= 10) {
      savingsScore = (120 + ((savingsRate - 10) / 10 * 80)).round();
      savingsStatus = 'Fair (10-20%)';
    } else if (savingsRate > 0) {
      savingsScore = (50 + (savingsRate / 10 * 70)).round();
      savingsStatus = 'Modest (<10%)';
    } else {
      savingsScore = 20;
      savingsStatus = 'Negative (Deficit)';
    }

    // 2. Pillar 2: Budget Adherence (0 - 250 pts)
    int budgetScore = 250;
    String budgetStatus = 'No active limits';
    if (budgets.isNotEmpty) {
      int exceededCount = 0;
      int nearLimitCount = 0;
      for (final b in budgets) {
        final spent = currentMonthCategorySpending[b.categoryId] ?? 0.0;
        if (spent > b.monthlyLimit) {
          exceededCount++;
        } else if (spent >= b.monthlyLimit * 0.8) {
          nearLimitCount++;
        }
      }

      final penalty = (exceededCount * 75) + (nearLimitCount * 25);
      budgetScore = max(40, 250 - penalty);
      if (exceededCount == 0 && nearLimitCount == 0) {
        budgetStatus = '100% On Track';
      } else if (exceededCount == 0) {
        budgetStatus = '$nearLimitCount Nearing Limit';
      } else {
        budgetStatus = '$exceededCount Exceeded';
      }
    }

    // 3. Pillar 3: Debt & Leverage Ratio (0 - 250 pts)
    int debtScore = 250;
    String debtStatus = 'Debt Free';
    if (totalBorrowed > 0) {
      final debtToIncomeRatio = totalIncome > 0 ? (totalBorrowed / totalIncome) : 1.0;
      if (debtToIncomeRatio <= 0.15) {
        debtScore = 220;
        debtStatus = 'Minimal (<15% income)';
      } else if (debtToIncomeRatio <= 0.35) {
        debtScore = 160;
        debtStatus = 'Moderate (15-35%)';
      } else if (debtToIncomeRatio <= 0.60) {
        debtScore = 100;
        debtStatus = 'Elevated (35-60%)';
      } else {
        debtScore = 40;
        debtStatus = 'High Burden (>60%)';
      }
    }

    // 4. Pillar 4: Emergency Cushion & Savings Goals (0 - 200 pts)
    int cushionScore = 50;
    String cushionStatus = 'Building';
    final monthlyBurn = max(1000.0, totalExpense);
    final monthsCovered = liquidBalance / monthlyBurn;

    if (monthsCovered >= 6.0) {
      cushionScore = 200;
      cushionStatus = '6+ Months Reserve';
    } else if (monthsCovered >= 3.0) {
      cushionScore = (140 + ((monthsCovered - 3.0) / 3.0 * 60)).round();
      cushionStatus = '3-6 Months Cushion';
    } else if (monthsCovered >= 1.0) {
      cushionScore = (80 + ((monthsCovered - 1.0) / 2.0 * 60)).round();
      cushionStatus = '1-3 Months Cushion';
    } else {
      cushionScore = max(30, (monthsCovered * 80).round());
      cushionStatus = '< 1 Month Buffer';
    }

    // Add bonus if goals are actively being funded
    if (goals.isNotEmpty && goals.any((g) => g.currentSavedAmount > 0)) {
      cushionScore = min(200, cushionScore + 20);
    }

    // Total Composite Score (0 - 1000)
    final int totalScore = (savingsScore + budgetScore + debtScore + cushionScore).clamp(0, 1000);

    // Grade and Status
    String grade = 'B';
    String statusTitle = 'Healthy';
    String statusSummary = 'Your finances are well-managed with a consistent surplus and solid fundamentals.';

    if (totalScore >= 850) {
      grade = 'A+';
      statusTitle = 'Prime Financial Health';
      statusSummary = 'Exceptional discipline! You have robust savings, zero toxic debt, and strong emergency reserves.';
    } else if (totalScore >= 720) {
      grade = 'A';
      statusTitle = 'Strong & Resilient';
      statusSummary = 'Very healthy cash flow and budget discipline. Keep compounding your savings.';
    } else if (totalScore >= 580) {
      grade = 'B';
      statusTitle = 'Stable with Growth Areas';
      statusSummary = 'Stable baseline. Boosting your monthly savings rate will elevate your score significantly.';
    } else if (totalScore >= 420) {
      grade = 'C';
      statusTitle = 'Needs Attention';
      statusSummary = 'Spending is close to total income or debts require active repayment focus.';
    } else {
      grade = 'D';
      statusTitle = 'Critical Action Required';
      statusSummary = 'Expenses exceed income or high debt leverage is creating financial strain.';
    }

    // Actionable personalized tips
    final List<String> tips = [];
    if (savingsRate < 20) {
      tips.add('Aim to save at least 20% of monthly income before discretionary spending.');
    }
    if (totalBorrowed > 0) {
      tips.add('Prioritize settling borrowed balances to reclaim $currencySymbol${totalBorrowed.toStringAsFixed(0)} in net worth.');
    }
    if (monthsCovered < 3.0) {
      tips.add('Build an emergency fund covering 3-6 months of essential living expenses.');
    }
    if (budgets.isEmpty) {
      tips.add('Set category budget limits for Food and Shopping to prevent spending drift.');
    }
    if (tips.isEmpty) {
      tips.add('Consider directing surplus savings into long-term savings goals or investments.');
    }

    final pillars = [
      HealthPillarScore(
        name: 'Savings Rate',
        score: savingsScore,
        maxScore: 300,
        status: savingsStatus,
        detail: '${savingsRate.toStringAsFixed(1)}% of income saved',
      ),
      HealthPillarScore(
        name: 'Budget Discipline',
        score: budgetScore,
        maxScore: 250,
        status: budgetStatus,
        detail: budgets.isEmpty ? 'Set budgets to boost score' : '${budgets.length} categories tracked',
      ),
      HealthPillarScore(
        name: 'Debt Leverage',
        score: debtScore,
        maxScore: 250,
        status: debtStatus,
        detail: totalBorrowed > 0 ? '$currencySymbol${totalBorrowed.toStringAsFixed(0)} owed' : 'Zero debt',
      ),
      HealthPillarScore(
        name: 'Emergency Cushion',
        score: cushionScore,
        maxScore: 200,
        status: cushionStatus,
        detail: '${monthsCovered.toStringAsFixed(1)} months of burn covered',
      ),
    ];

    return FinancialHealthReport(
      totalScore: totalScore,
      grade: grade,
      statusTitle: statusTitle,
      statusSummary: statusSummary,
      pillars: pillars,
      actionableTips: tips,
    );
  }
}
