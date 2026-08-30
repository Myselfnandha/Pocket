import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/models/recurring_model.dart';
import 'package:pocket/models/budget_model.dart';
import 'package:pocket/models/goal_model.dart';
import 'package:pocket/services/ai_forecasting_service.dart';
import 'package:pocket/services/anomaly_detection_service.dart';
import 'package:pocket/services/nlp_parser_service.dart';
import 'package:pocket/services/learning_suggest_service.dart';
import 'package:pocket/services/financial_health_service.dart';
import 'package:pocket/services/inflation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI & Predictive Intelligence Suite', () {
    test('AiForecastingService computes burn rate, confidence intervals, and sparklines', () {
      final refDate = DateTime(2026, 8, 15);
      final txs = [
        TransactionModel(
          id: 'tx1',
          title: 'Groceries',
          amount: 1500.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'bank',
          date: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 8, 5),
        ),
        TransactionModel(
          id: 'tx2',
          title: 'Dining',
          amount: 3000.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'bank',
          date: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 10),
        ),
      ];

      final recurringRules = [
        RecurringRuleModel(
          id: 'rec1',
          title: 'Wifi Bill',
          amount: 1000.0,
          type: TransactionType.expense,
          categoryId: 'bills',
          walletId: 'bank',
          dueDay: 25, // due later in month
          nextDueDate: DateTime(2026, 8, 25),
          createdAt: DateTime(2026, 8, 1),
        ),
      ];

      final forecast = AiForecastingService.calculateForecast(
        transactions: txs,
        recurringRules: recurringRules,
        totalLiquidBalance: 50000.0,
        referenceDate: refDate,
      );

      expect(forecast.currentMonthSpendSoFar, equals(4500.0));
      expect(forecast.daysElapsed, equals(15));
      expect(forecast.currentDailyBurnRate, equals(300.0)); // 4500 / 15
      expect(forecast.upcomingRecurringBillsTotal, equals(1000.0));
      expect(forecast.upperExpenseBound, greaterThanOrEqualTo(forecast.projectedMonthEndExpense));
      expect(forecast.lowerExpenseBound, lessThanOrEqualTo(forecast.projectedMonthEndExpense));
      expect(forecast.sparklineValues.length, equals(31));
    });

    test('AnomalyDetectionService flags unusually large transaction entries against category baseline', () {
      final pastTxs = [
        TransactionModel(
          id: 't1',
          title: 'Lunch',
          amount: 400.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'cash',
          date: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
        TransactionModel(
          id: 't2',
          title: 'Dinner',
          amount: 500.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'cash',
          date: DateTime(2026, 8, 2),
          createdAt: DateTime(2026, 8, 2),
        ),
        TransactionModel(
          id: 't3',
          title: 'Breakfast',
          amount: 450.0,
          type: TransactionType.expense,
          categoryId: 'food',
          walletId: 'cash',
          date: DateTime(2026, 8, 3),
          createdAt: DateTime(2026, 8, 3),
        ),
      ];

      // Normal entry of 600 should NOT trigger anomaly
      final normalResult = AnomalyDetectionService.checkAnomaly(
        amount: 600.0,
        categoryId: 'food',
        pastTransactions: pastTxs,
        categories: defaultCategories,
      );
      expect(normalResult.isAnomaly, isFalse);

      // Huge entry of 4500 (10x average) SHOULD trigger anomaly
      final anomalyResult = AnomalyDetectionService.checkAnomaly(
        amount: 4500.0,
        categoryId: 'food',
        pastTransactions: pastTxs,
        categories: defaultCategories,
      );
      expect(anomalyResult.isAnomaly, isTrue);
      expect(anomalyResult.multipleOfAverage, greaterThanOrEqualTo(3.5));
      expect(anomalyResult.message, contains('Unusually large entry'));
    });

    test('NlpTransactionParser parses natural language input with relative dates, amounts, and categories', () {
      final parsedDinner = NlpTransactionParser.parse(
        '1200 for dinner with friends yesterday',
        categories: defaultCategories,
        wallets: defaultWallets,
      );
      expect(parsedDinner.amount, equals(1200.0));
      expect(parsedDinner.type, equals(TransactionType.expense));
      expect(parsedDinner.categoryId, equals('food'));
      expect(parsedDinner.date.day, equals(DateTime.now().subtract(const Duration(days: 1)).day));

      final parsedSalary = NlpTransactionParser.parse(
        'received 50000 salary from company',
        categories: defaultCategories,
        wallets: defaultWallets,
      );
      expect(parsedSalary.amount, equals(50000.0));
      expect(parsedSalary.type, equals(TransactionType.income));
      expect(parsedSalary.categoryId, equals('salary'));

      final customWallets = [
        const WalletModel(
          id: 'w_custom_bank',
          name: 'dd',
          icon: '🏦',
          colorValue: 0xFF2E7D32,
          initialBalance: 0.0,
          currentBalance: 5000.0,
          walletType: WalletType.bank,
          accountNumber: '4482',
        ),
        const WalletModel(
          id: 'w_custom_cash',
          name: 'Cash in Hand',
          icon: '💵',
          colorValue: 0xFF4CAF50,
          initialBalance: 0.0,
          currentBalance: 1200.0,
          walletType: WalletType.cash,
        ),
      ];

      // Test "dinner yesterday through bank account" matches bank wallet "dd"
      final parsedBankPhrase = NlpTransactionParser.parse(
        'dinner yesterday through bank account 1200',
        categories: defaultCategories,
        wallets: customWallets,
      );
      expect(parsedBankPhrase.amount, equals(1200.0));
      expect(parsedBankPhrase.walletId, equals('w_custom_bank'));
      expect(parsedBankPhrase.title, equals('Dinner'));

      // Test account last 4 digits matching
      final parsedByDigits = NlpTransactionParser.parse(
        'paid 500 for coffee via 4482',
        categories: defaultCategories,
        wallets: customWallets,
      );
      expect(parsedByDigits.amount, equals(500.0));
      expect(parsedByDigits.walletId, equals('w_custom_bank'));

      final parsedK = NlpTransactionParser.parse(
        'paid 2.5k electricity bill via bank',
        categories: defaultCategories,
        wallets: defaultWallets,
      );
      expect(parsedK.amount, equals(2500.0));
      expect(parsedK.categoryId, anyOf('bills', 'utilities'));
    });

    test('LearningSuggestService learns merchant corrections and suggests priority category', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      LearningSuggestService.clearMemoryForTesting();
      await LearningSuggestService.init(prefs);

      // Teach merchant correction
      await LearningSuggestService.recordCorrection(
        merchantTitle: 'Swiggy Instamart Order',
        categoryId: 'food',
        prefs: prefs,
      );

      final suggested = LearningSuggestService.suggestCategory(
        title: 'Swiggy Dinner',
        categories: defaultCategories,
      );
      expect(suggested, equals('food'));
    });

    test('FinancialHealthService computes 0-1000 score with pillar breakdown and actionable tips', () {
      final report = FinancialHealthService.calculateScore(
        totalIncome: 100000.0,
        totalExpense: 60000.0,
        budgets: [
          CategoryBudgetModel(
            id: 'b1',
            categoryId: 'food',
            monthlyLimit: 15000.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        currentMonthCategorySpending: {'food': 8000.0},
        debts: [],
        wallets: [
          WalletModel(
            id: 'w1',
            name: 'Savings',
            icon: '🏦',
            colorValue: 0xFF4CAF50,
            walletType: WalletType.bank,
            initialBalance: 300000.0,
            currentBalance: 300000.0,
          ),
        ],
        goals: [
          GoalModel(
            id: 'g1',
            title: 'House Downpayment',
            targetAmount: 500000.0,
            currentSavedAmount: 150000.0,
            colorValue: 0xFF00E676,
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(report.totalScore, greaterThanOrEqualTo(700));
      expect(report.totalScore, lessThanOrEqualTo(1000));
      expect(report.grade, anyOf('A', 'A+'));
      expect(report.pillars.length, equals(4));
    });

    test('InflationService calculates purchasing power equivalent over time', () {
      final pastDate = DateTime(2024, 1, 1);
      final today = DateTime(2026, 1, 1); // exactly 2 years

      final result = InflationService.calculatePurchasingPower(
        pastAmount: 50000.0,
        pastDate: pastDate,
        today: today,
        annualInflationRate: 0.06, // 6%
      );

      // (1.06)^2 * 50,000 = 1.1236 * 50,000 = 56,180
      expect(result.equivalentAmountToday, closeTo(56180.0, 50.0));
      expect(result.yearDifference, closeTo(2.0, 0.05));
      expect(result.purchasingPowerLossPercent, greaterThan(10.0));
    });
  });
}
