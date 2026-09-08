import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket/models/budget_model.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/debt_model.dart';
import 'package:pocket/models/goal_model.dart';
import 'package:pocket/models/notification_model.dart';
import 'package:pocket/models/recurring_model.dart';
import 'package:pocket/models/settings_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/providers/app_providers.dart';
import 'package:pocket/services/ai_forecasting_service.dart';
import 'package:pocket/services/anomaly_detection_service.dart';
import 'package:pocket/services/backup_service.dart';
import 'package:pocket/services/cloud_sync_service.dart';
import 'package:pocket/services/financial_health_service.dart';
import 'package:pocket/services/inflation_service.dart';
import 'package:pocket/services/learning_suggest_service.dart';
import 'package:pocket/services/nlp_parser_service.dart';
import 'package:pocket/services/notification_service.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:pocket/services/system_widget_service.dart';
import 'package:pocket/services/upi_screenshot_parser_service.dart';
import 'package:pocket/screens/onboarding/onboarding_screen.dart';
import 'package:pocket/screens/home/home_screen.dart';
import 'package:pocket/screens/transactions/transactions_list_screen.dart';
import 'package:pocket/screens/transactions/add_transaction_screen.dart';
import 'package:pocket/screens/analytics/analytics_screen.dart';
import 'package:pocket/screens/wallets/wallets_screen.dart';
import 'package:pocket/screens/debts/debts_screen.dart';
import 'package:pocket/screens/settings/settings_screen.dart';
import 'package:pocket/screens/settings/data_management_screen.dart';
import 'package:pocket/widgets/balance_card.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Pocket Full End-to-End Application & Service Verification Suite', () {
    late StorageService storage;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_sign_in'), (MethodCall call) async {
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (MethodCall call) async {
        return true;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('es.antonborries.home_widget/home_widget'), (MethodCall call) async {
        return true;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.pocket.pocket/widget_events'), (MethodCall call) async {
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (MethodCall call) async {
        return true;
      });
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      storage = await StorageService.init();
    });

    testWidgets('E2E Flow 1: Onboarding Journey with Real-time Theme & Account Setup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      // 1. Welcome Screen
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Welcome to Pocket'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Advance to Profile Setup
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Profile Setup'), findsOneWidget);

      // Enter profile details
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alex Morgan');
      await tester.pump();

      // Advance to Theme & Display
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Theme & Display'), findsOneWidget);

      // Verify Real-time theme toggle
      await tester.tap(find.text('Dark Theme'));
      await tester.pump();
      expect(container.read(settingsProvider).themeMode, equals(AppThemeMode.manual));
      expect(container.read(settingsProvider).manualThemeStyle, equals(ManualThemeStyle.dark));

      // Advance to Wallet Setup
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Wallet Setup'), findsOneWidget);

      // Add a Bank Account
      await tester.tap(find.text('+ Bank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Canara Bank');
      await tester.enterText(textFields.at(1), '4821');
      await tester.enterText(textFields.at(2), '50000');
      await tester.pump();

      await tester.tap(find.text('Save Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Advance to Categories
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Spending Categories'), findsOneWidget);

      // Advance to Category Budgets
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Monthly Budgets & Rollover'), findsOneWidget);

      // Advance to Preferences & Smart Alerts
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Smart Alerts & Launch'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('E2E Flow 2: Multi-Wallet Engine, Real Transactions & NLP Parsing', (tester) async {
      // 1. Setup realistic bank accounts & cash wallets
      final canaraBank = WalletModel(
        id: 'canara-bank',
        name: 'Canara Bank',
        walletType: WalletType.bank,
        icon: '🏦',
        colorValue: 0xFF2196F3,
        initialBalance: 50000.0,
        currentBalance: 50000.0,
        accountNumber: '4821',
      );

      final cashWallet = WalletModel(
        id: 'pocket-cash',
        name: 'Cash in Hand',
        walletType: WalletType.cash,
        icon: '💵',
        colorValue: 0xFF4CAF50,
        initialBalance: 5000.0,
        currentBalance: 5000.0,
      );

      final upiWallet = WalletModel(
        id: 'gpay-upi',
        name: 'GPay UPI',
        walletType: WalletType.upi,
        icon: '📱',
        colorValue: 0xFFFF9800,
        initialBalance: 12000.0,
        currentBalance: 12000.0,
      );

      await storage.saveWallets([canaraBank, cashWallet, upiWallet]);
      expect(storage.getWallets().length, equals(3));

      // 2. Test NLP Engine matching custom bank names & last-4 digits
      final nlp1 = NlpTransactionParser.parse(
        'Paid 1850 for team dinner yesterday night on Canara Bank',
        categories: defaultCategories,
        wallets: storage.getWallets(),
      );
      expect(nlp1.amount, equals(1850.0));
      expect(nlp1.walletId, equals('canara-bank'));
      expect(nlp1.type, equals(TransactionType.expense));
      expect(nlp1.categoryId, equals('food'));

      final nlp2 = NlpTransactionParser.parse(
        'Received 45000 salary in 4821',
        categories: defaultCategories,
        wallets: storage.getWallets(),
      );
      expect(nlp2.amount, equals(45000.0));
      expect(nlp2.walletId, equals('canara-bank'));
      expect(nlp2.type, equals(TransactionType.income));
      expect(nlp2.categoryId, equals('salary'));

      // 3. Log real transactions and verify balance calculations
      final tx1 = TransactionModel(
        id: 'tx-1',
        title: 'Team Dinner',
        amount: 1850.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'canara-bank',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final tx2 = TransactionModel(
        id: 'tx-2',
        title: 'Freelance Design Payment',
        amount: 25000.0,
        type: TransactionType.income,
        categoryId: 'freelance',
        walletId: 'gpay-upi',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final tx3 = TransactionModel(
        id: 'tx-3',
        title: 'Grocery Supplies',
        amount: 1200.0,
        type: TransactionType.expense,
        categoryId: 'groceries',
        walletId: 'pocket-cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await storage.saveTransactions([tx1, tx2, tx3]);
      expect(storage.getTransactions().length, equals(3));

      // Verify balances via ProviderContainer
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      final walletsWithBalances = container.read(walletsWithBalancesProvider);
      final updatedCanara = walletsWithBalances.firstWhere((w) => w.id == 'canara-bank');
      expect(updatedCanara.currentBalance, equals(50000.0 - 1850.0));

      final updatedGpay = walletsWithBalances.firstWhere((w) => w.id == 'gpay-upi');
      expect(updatedGpay.currentBalance, equals(12000.0 + 25000.0));

      final updatedCash = walletsWithBalances.firstWhere((w) => w.id == 'pocket-cash');
      expect(updatedCash.currentBalance, equals(5000.0 - 1200.0));

      final totalBalance = container.read(totalBalanceProvider);
      expect(totalBalance, equals((50000.0 - 1850.0) + (12000.0 + 25000.0) + (5000.0 - 1200.0)));
    });

    testWidgets('E2E Flow 3: Budgets, Rollover, and Savings Goals Engine', (tester) async {
      // 1. Configure category budgets
      final foodBudget = CategoryBudgetModel(
        id: 'budget-food-1',
        categoryId: 'food',
        monthlyLimit: 10000.0,
        isRolloverEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.saveCategoryBudgets([foodBudget]);

      // 2. Configure Savings Goals
      final emergencyGoal = GoalModel(
        id: 'goal-emergency',
        title: 'Emergency Safety Vault',
        targetAmount: 100000.0,
        currentSavedAmount: 35000.0,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        colorValue: 0xFF4CAF50,
        createdAt: DateTime.now(),
      );
      await storage.saveGoals([emergencyGoal]);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      final budgets = container.read(categoryBudgetsProvider);
      expect(budgets.length, equals(1));
      expect(budgets.first.monthlyLimit, equals(10000.0));

      final goals = container.read(goalsProvider);
      expect(goals.length, equals(1));
      expect(goals.first.progress, closeTo(0.35, 0.01));

      // Test contributing to goal
      final updatedGoal = emergencyGoal.copyWith(
        currentSavedAmount: emergencyGoal.currentSavedAmount + 15000.0,
      );
      await storage.saveGoals([updatedGoal]);
      expect(storage.getGoals().first.currentSavedAmount, equals(50000.0));
      expect(storage.getGoals().first.progress, closeTo(0.50, 0.01));

      // 3. Configure and process Recurring Rules
      final rentRule = RecurringRuleModel(
        id: 'rule-rent-1',
        title: 'Apartment Rent',
        amount: 22000.0,
        type: TransactionType.expense,
        categoryId: 'rent',
        walletId: 'canara-bank',
        dueDay: DateTime.now().day,
        nextDueDate: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      await storage.saveRecurringRules([rentRule]);
      final generatedCount = await storage.processDueRecurringRules();
      expect(generatedCount, equals(1));
      expect(storage.getTransactions().any((t) => t.title == 'Apartment Rent'), isTrue);
    });

    testWidgets('E2E Flow 4: Debts & Lending Ledger with Partial & Full Settlement', (tester) async {
      final lentDebt = DebtModel(
        id: 'debt-lent-1',
        type: DebtType.lent,
        personName: 'Vikram Sharma',
        totalAmount: 8000.0,
        remainingAmount: 8000.0,
        dueDate: DateTime.now().add(const Duration(days: 15)),
        createdAt: DateTime.now(),
      );

      final borrowedDebt = DebtModel(
        id: 'debt-borrowed-1',
        type: DebtType.borrowed,
        personName: 'Rohan Mehta',
        totalAmount: 3500.0,
        remainingAmount: 3500.0,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
      );

      await storage.saveDebts([lentDebt, borrowedDebt]);
      expect(storage.getDebts().length, equals(2));

      // Partial Repayment on Lent Debt
      final updatedLent = lentDebt.recordPayment(
        paymentAmount: 3000.0,
        note: 'UPI part payment',
      );
      await storage.saveDebts([updatedLent, borrowedDebt]);

      final savedLent = storage.getDebts().firstWhere((d) => d.id == 'debt-lent-1');
      expect(savedLent.remainingAmount, equals(5000.0));
      expect(savedLent.isSettled, isFalse);

      // Settle full borrowed debt
      final settledBorrowed = borrowedDebt.recordPayment(
        paymentAmount: 3500.0,
        note: 'Full settlement',
      );
      await storage.saveDebts([updatedLent, settledBorrowed]);

      final savedBorrowed = storage.getDebts().firstWhere((d) => d.id == 'debt-borrowed-1');
      expect(savedBorrowed.isSettled, isTrue);
      expect(savedBorrowed.remainingAmount, equals(0.0));
    });

    testWidgets('E2E Flow 5: AI Forecasting, Anomaly Detection & Financial Health Analytics', (tester) async {
      final now = DateTime(2026, 8, 20);
      final List<TransactionModel> historicalTxs = [];

      // Generate daily transactions for statistical forecasting
      for (int i = 1; i <= 15; i++) {
        historicalTxs.add(
          TransactionModel(
            id: 'tx-hist-$i',
            title: 'Daily Meal $i',
            amount: 400.0,
            type: TransactionType.expense,
            categoryId: 'food',
            walletId: 'bank',
            date: DateTime(2026, 8, i),
            createdAt: DateTime(2026, 8, i),
          ),
        );
      }

      await storage.saveTransactions(historicalTxs);

      // 1. Test AI Forecasting Service
      final forecast = AiForecastingService.calculateForecast(
        transactions: historicalTxs,
        recurringRules: [],
        totalLiquidBalance: 80000.0,
        referenceDate: now,
      );
      expect(forecast.currentMonthSpendSoFar, equals(6000.0));
      expect(forecast.daysElapsed, equals(20));
      expect(forecast.currentDailyBurnRate, equals(300.0));
      expect(forecast.projectedMonthEndExpense, greaterThan(0));

      // 2. Test Anomaly Detection Service
      final anomalyResult = AnomalyDetectionService.checkAnomaly(
        amount: 6500.0,
        categoryId: 'food',
        pastTransactions: historicalTxs,
        categories: defaultCategories,
      );
      expect(anomalyResult.isAnomaly, isTrue);

      final normalResult = AnomalyDetectionService.checkAnomaly(
        amount: 420.0,
        categoryId: 'food',
        pastTransactions: historicalTxs,
        categories: defaultCategories,
      );
      expect(normalResult.isAnomaly, isFalse);

      // 3. Test Financial Health Score (0-1000)
      final report = FinancialHealthService.calculateScore(
        totalIncome: 75000.0,
        totalExpense: 25000.0,
        budgets: [],
        currentMonthCategorySpending: {'food': 6000.0},
        debts: [],
        wallets: [
          WalletModel(
            id: 'bank',
            name: 'Bank',
            icon: '🏦',
            colorValue: 0xFF2196F3,
            walletType: WalletType.bank,
            initialBalance: 100000.0,
            currentBalance: 100000.0,
          ),
        ],
        goals: [],
      );

      expect(report.totalScore, inInclusiveRange(0, 1000));
      expect(report.pillars.length, equals(4));

      // 4. Test Inflation & Learning Services
      final inflation = InflationService.calculatePurchasingPower(
        pastAmount: 10000.0,
        pastDate: DateTime(2024, 1, 1),
        today: DateTime(2026, 1, 1),
        annualInflationRate: 0.06,
      );
      expect(inflation.equivalentAmountToday, greaterThan(10000.0));

      final prefs = await SharedPreferences.getInstance();
      await LearningSuggestService.init(prefs);
      await LearningSuggestService.recordCorrection(
        merchantTitle: 'Swiggy',
        categoryId: 'food',
        prefs: prefs,
      );
      final learnedCat = LearningSuggestService.suggestCategory(
        title: 'Swiggy Dinner',
        categories: defaultCategories,
      );
      expect(learnedCat, equals('food'));

      // 5. Test UPI Screenshot Parser heuristic
      final upiParsed = UpiScreenshotParserService.predictCategory('Swiggy Order', 'Paid 450');
      expect(upiParsed, equals('cat_food'));
    });

    testWidgets('E2E Flow 6: Database Snapshot Export, Restoration & Cloud Sync Handlers', (tester) async {
      final testTx = TransactionModel(
        id: 'restore-tx-1',
        title: 'Cloud Backup Target',
        amount: 999.0,
        type: TransactionType.expense,
        categoryId: 'entertainment',
        walletId: 'bank',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await storage.saveTransactions([testTx]);

      // 1. Export database snapshot
      final backup = BackupService(storage);
      final jsonSnapshot = backup.exportJsonBackupString();
      expect(jsonSnapshot.isNotEmpty, isTrue);

      // 2. Clear local storage
      await storage.clearAllData();
      expect(storage.getTransactions().isEmpty, isTrue);

      // 3. Restore snapshot
      final restoreSuccess = await backup.restoreFromJsonString(jsonSnapshot);
      expect(restoreSuccess, isTrue);
      expect(storage.getTransactions().length, equals(1));
      expect(storage.getTransactions().first.title, equals('Cloud Backup Target'));

      // 4. Test CloudSyncService manual token setting
      final cloudService = CloudSyncService();
      await cloudService.setManualAccessToken(
        token: 'ya29.test_token_oauth_dummy',
        email: 'developer.pocket@gmail.com',
      );
      expect(cloudService.isSignedIn, isTrue);
      expect(cloudService.userEmail, equals('developer.pocket@gmail.com'));
      final authHeaders = await cloudService.getAuthHeaders();
      expect(authHeaders['Authorization'], equals('Bearer ya29.test_token_oauth_dummy'));

      await cloudService.signOut();
      expect(cloudService.isSignedIn, isFalse);

      // 5. Notifications & Widget Sync verification
      final notif = AppNotificationModel(
        id: 'n-1',
        title: 'Daily Summary',
        message: 'All daily metrics updated',
        type: NotificationType.dailyReminder,
        createdAt: DateTime.now(),
      );
      await storage.addNotification(notif);
      expect(storage.getNotifications().length, equals(1));

      // Test SystemWidgetService update & clear
      await SystemWidgetService.updateWidgetData(
        totalBalance: 50000.0,
        todayExpense: 450.0,
        currencySymbol: '₹',
        wallets: storage.getWallets(),
      );

      // Test Notification Service instance initialization
      expect(NotificationService(), isNotNull);
    });

    testWidgets('E2E Flow 7: Full Screen Suite Navigation & Render Verification', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final wallet = WalletModel(
        id: 'main-bank',
        name: 'Main Checking',
        icon: '🏦',
        colorValue: 0xFF2196F3,
        walletType: WalletType.bank,
        initialBalance: 75000.0,
        currentBalance: 75000.0,
      );
      await storage.saveWallets([wallet]);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      // 1. HomeScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BalanceCard), findsOneWidget);

      // 2. TransactionsListScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransactionsListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Transactions'), findsOneWidget);

      // 3. AddTransactionScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddTransactionScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add Transaction'), findsOneWidget);

      // 4. AnalyticsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Analytics & Budgets'), findsOneWidget);

      // 5. WalletsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WalletsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Wallets & Accounts'), findsOneWidget);

      // 6. DebtsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DebtsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Debts & Loans'), findsOneWidget);

      // 7. SettingsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Settings'), findsOneWidget);

      // 8. DataManagementScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DataManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Data & Cloud Sync'), findsOneWidget);
      expect(find.text('Cloud Database Sync'), findsOneWidget);
    });
  });
}
