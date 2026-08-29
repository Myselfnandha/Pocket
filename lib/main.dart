import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/category_model.dart';
import 'navigation/app_router.dart';
import 'providers/app_providers.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/system_widget_service.dart';
import 'theme/app_theme.dart';
import 'widgets/quick_add_transaction_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();
  await NotificationService().init();

  // Process any due recurring transactions automatically
  await storageService.processDueRecurringRules();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const PocketApp(),
    ),
  );
}

class PocketApp extends ConsumerStatefulWidget {
  const PocketApp({super.key});

  @override
  ConsumerState<PocketApp> createState() => _PocketAppState();
}

class _PocketAppState extends ConsumerState<PocketApp> {
  late final _router = createRouter(
    ref.read(settingsProvider).isOnboarded,
  );

  @override
  void initState() {
    super.initState();
    SystemWidgetService.registerWidgetLaunchCallback((uri) {
      _handleWidgetLaunch(uri);
    });
  }

  void _handleWidgetLaunch(Uri uri) {
    if (uri.host == 'quick-add' || uri.path.contains('quick-add')) {
      final typeParam = uri.queryParameters['type'];
      final initialType = typeParam == 'income' ? TransactionType.income : TransactionType.expense;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null) {
          QuickAddTransactionDialog.show(navContext, initialType: initialType);
        }
      });
    }
  }

  @override
  void dispose() {
    SystemWidgetService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(effectiveThemeModeProvider);
    final darkTheme = ref.watch(activeDarkThemeProvider);

    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final settings = ref.watch(settingsProvider);

    // Sync real-time balance and today's spend to Android System Home Screen App Widget
    SystemWidgetService.updateWidgetData(
      totalBalance: totalBalance,
      todayExpense: monthlyStats.todayExpense,
      currencySymbol: settings.currencySymbol,
    );

    return MaterialApp.router(
      title: 'Pocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

