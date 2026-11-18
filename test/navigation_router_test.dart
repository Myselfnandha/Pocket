import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocket/l10n/generated/app_localizations.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/notification_model.dart';
import 'package:pocket/models/transaction_model.dart';
import 'package:pocket/navigation/app_router.dart';
import 'package:pocket/providers/app_providers.dart';
import 'package:pocket/screens/analytics/analytics_screen.dart';
import 'package:pocket/screens/debts/debts_screen.dart';
import 'package:pocket/screens/onboarding/onboarding_screen.dart';
import 'package:pocket/screens/settings/auto_import_studio_screen.dart';
import 'package:pocket/screens/settings/data_management_screen.dart';
import 'package:pocket/screens/settings/recurring_rules_screen.dart';
import 'package:pocket/screens/settings/widgets_customizer_screen.dart';
import 'package:pocket/screens/splash/splash_screen.dart';
import 'package:pocket/screens/transactions/edit_transaction_screen.dart';
import 'package:pocket/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Pocket Navigation & Route Deep-Link Suite', () {
    late StorageService storage;

    setUp(() async {
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

    Widget createTestApp(GoRouter router) {
      return ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('Route: /splash renders SplashScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('Route: /onboarding renders OnboardingScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(false);
      await tester.pumpWidget(createTestApp(router));
      router.go('/onboarding');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Welcome to Pocket'), findsOneWidget);
    });

    testWidgets('Route: /budgets opens AnalyticsScreen with AI & Budget tab (Tab 2)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/budgets');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(find.text('AI & Budget'), findsOneWidget);
    });

    testWidgets('Route: /budget alias opens AnalyticsScreen with AI & Budget tab (Tab 2)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/budget');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(find.text('AI & Budget'), findsOneWidget);
    });

    testWidgets('Route: /analytics?tab=2 opens AnalyticsScreen with AI & Budget tab', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/analytics?tab=2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(find.text('AI & Budget'), findsOneWidget);
    });

    testWidgets('Route: /debts renders DebtsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/debts');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DebtsScreen), findsOneWidget);
      expect(find.text('Debts & Loans'), findsOneWidget);
    });

    testWidgets('Route: /recurring-rules renders RecurringRulesScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/recurring-rules');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RecurringRulesScreen), findsOneWidget);
      expect(find.text('Recurring Expenses'), findsOneWidget);
    });

    testWidgets('Route: /data-management renders DataManagementScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/data-management');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DataManagementScreen), findsOneWidget);
      expect(find.text('Data Management'), findsOneWidget);
      expect(find.text('LOCAL DATA VAULT'), findsOneWidget);
    });

    testWidgets('Route: /auto-import-studio renders AutoImportStudioScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/auto-import-studio');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AutoImportStudioScreen), findsOneWidget);
      expect(find.text('Auto-Import Studio'), findsOneWidget);
    });

    testWidgets('Route: /widget-customizer renders WidgetsCustomizerScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/widget-customizer');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WidgetsCustomizerScreen), findsOneWidget);
      expect(find.text('Home Screen Widgets'), findsOneWidget);
    });

    testWidgets('Route: /edit-transaction renders EditTransactionScreen with extra model', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tx = TransactionModel(
        id: 'tx_nav_test',
        title: 'Grocery Store Run',
        amount: 850.0,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.push('/edit-transaction', extra: tx);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EditTransactionScreen), findsOneWidget);
      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('Grocery Store Run'), findsOneWidget);
    });

    testWidgets('Notification tap routes intelligently to relevant screens', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Save a budget warning notification
      await storage.saveNotifications([
        AppNotificationModel(
          id: 'notif_b_1',
          title: 'Budget Warning',
          message: 'You have reached 80% of Food budget',
          type: NotificationType.budgetNearLimit,
          createdAt: DateTime.now(),
        ),
      ]);

      final router = createRouter(true);
      await tester.pumpWidget(createTestApp(router));
      router.go('/notifications');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Budget Warning'), findsOneWidget);

      // Tap notification item
      await tester.tap(find.text('Budget Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verified it navigated to /budgets (AI & Budget tab)
      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(find.text('AI & Budget'), findsOneWidget);
    });
  });
}
