import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/category_model.dart';
import 'navigation/app_router.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';
import 'services/shared_transaction_handler.dart';
import 'services/storage_service.dart';
import 'services/supabase_sync_service.dart';
import 'services/system_widget_service.dart';
import 'services/upi_screenshot_parser_service.dart';
import 'widgets/quick_add_transaction_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();
  await NotificationService().init();
  await SupabaseSyncService().init();

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

class _PocketAppState extends ConsumerState<PocketApp> with WidgetsBindingObserver {
  late final _router = createRouter(
    ref.read(settingsProvider).isOnboarded,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Android System Home Screen App Widget Launch Listener
    SystemWidgetService.registerWidgetLaunchCallback((uri) {
      _handleWidgetLaunch(uri);
    });

    // 2. Shared UPI Screenshot & Banking Intent Listener
    SharedTransactionHandler.initialize(
      onTransactionReceived: (parsed) {
        _handleSharedTransaction(parsed);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh transactions and wallets whenever returning from widget popup or notification
      ref.read(transactionsProvider.notifier).refreshFromDisk();
      ref.read(walletsProvider.notifier).refreshFromDisk();
      ref.read(notificationsProvider.notifier).refreshFromDisk();
    }
  }

  void _handleWidgetLaunch(Uri uri) {
    final uriStr = uri.toString();
    // If the intent is for the standalone transparent QuickAddActivity, it already renders QuickAddDialogScreen directly.
    if (uriStr.contains('quick-add-dialog') || uri.host == 'quick-add-dialog') {
      return;
    }

    if (uri.host == 'quick-add' || uri.path == '/quick-add' || uri.path == 'quick-add') {
      if (QuickAddTransactionDialog.isOpen) return;

      final typeParam = uri.queryParameters['type'];
      final initialType = typeParam == 'income' ? TransactionType.income : TransactionType.expense;

      void showPopup([int retries = 0]) {
        if (!mounted || QuickAddTransactionDialog.isOpen) return;
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          QuickAddTransactionDialog.show(navContext, initialType: initialType);
        } else if (retries < 12) {
          Future.delayed(const Duration(milliseconds: 100), () {
            showPopup(retries + 1);
          });
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => showPopup());
    }
  }

  void _handleSharedTransaction(UpiParsedTransaction tx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        QuickAddTransactionDialog.show(
          navContext,
          initialType: tx.isIncome ? TransactionType.income : TransactionType.expense,
          initialAmount: tx.amount,
          initialTitle: tx.merchant,
          initialCategoryId: tx.suggestedCategoryId,
          initialReceiptImagePath: tx.imagePath,
          initialSenderName: tx.senderName,
          initialReceiverName: tx.receiverName,
          initialRefId: tx.refId,
          initialCounterpartyLast4: tx.counterpartyLast4,
          initialNote: null, // Note field remains completely clean for user
          autoFocusNote: false,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemWidgetService.dispose();
    SharedTransactionHandler.dispose();
    super.dispose();
  }

  void _syncWidget() {
    final totalBalance = ref.read(totalBalanceProvider);
    final monthlyStats = ref.read(monthlyStatsProvider);
    final settings = ref.read(settingsProvider);
    final wallets = ref.read(walletsWithBalancesProvider);

    SystemWidgetService.updateWidgetData(
      totalBalance: totalBalance,
      todayExpense: monthlyStats.todayExpense,
      currencySymbol: settings.currencySymbol,
      wallets: wallets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(effectiveThemeModeProvider);
    final darkTheme = ref.watch(activeDarkThemeProvider);
    final lightTheme = ref.watch(activeLightThemeProvider);

    // Reactive listeners: sync Android System Widget immediately on ANY state mutation
    ref.listen<double>(totalBalanceProvider, (prev, next) => _syncWidget());
    ref.listen<MonthlyStats>(monthlyStatsProvider, (prev, next) => _syncWidget());
    ref.listen(walletsWithBalancesProvider, (prev, next) => _syncWidget());
    ref.listen(settingsProvider, (prev, next) => _syncWidget());

    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final settings = ref.watch(settingsProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);

    // Initial sync
    SystemWidgetService.updateWidgetData(
      totalBalance: totalBalance,
      todayExpense: monthlyStats.todayExpense,
      currencySymbol: settings.currencySymbol,
      wallets: wallets,
    );

    return MaterialApp.router(
      title: 'Pocket',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
