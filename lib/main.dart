import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'models/category_model.dart';
import 'navigation/app_router.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';
import 'services/receipt_service.dart';
import 'services/shared_transaction_handler.dart';
import 'services/storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/system_widget_service.dart';
import 'services/upi_screenshot_parser_service.dart';
import 'widgets/nlp_quick_add_modal.dart';
import 'widgets/quick_add_transaction_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();
  await NotificationService().init();
  await CloudSyncService().init();

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
      ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
    }
  }

  void _handleWidgetLaunch(Uri uri) {
    final uriStr = uri.toString();
    // If the intent is for the standalone transparent QuickAddActivity, it already renders QuickAddDialogScreen directly.
    if (uriStr.contains('quick-add-dialog') || uri.host == 'quick-add-dialog') {
      return;
    }

    void executeWithContext(void Function(BuildContext ctx) action, [int retries = 0]) {
      if (!mounted) return;
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        action(navContext);
      } else if (retries < 12) {
        Future.delayed(const Duration(milliseconds: 100), () {
          executeWithContext(action, retries + 1);
        });
      }
    }

    // 1. Scan Receipt via Camera
    if (uri.host == 'scan' || uri.path.contains('scan')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        executeWithContext((ctx) async {
          final receiptFile = await ReceiptService().pickOrCaptureReceipt(source: ImageSource.camera);
          if (receiptFile != null && ctx.mounted) {
            QuickAddTransactionDialog.show(
              ctx,
              initialReceiptImagePath: receiptFile.path,
              initialType: TransactionType.expense,
            );
          }
        });
      });
      return;
    }

    // 2. Voice / NLP AI Quick Add
    if (uri.host == 'voice' || uri.path.contains('voice')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        executeWithContext((ctx) {
          NlpQuickAddModal.show(ctx);
        });
      });
      return;
    }

    // 3. Budgets Deep Link
    if (uri.host == 'budget' || uri.path.contains('budget')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        executeWithContext((ctx) {
          ctx.go('/budgets');
        });
      });
      return;
    }

    // 4. Quick Add Dialog Launch
    if (uri.host == 'quick-add' || uri.path == '/quick-add' || uri.path == 'quick-add') {
      if (QuickAddTransactionDialog.isOpen) return;

      final typeParam = uri.queryParameters['type'];
      final initialType = typeParam == 'income' ? TransactionType.income : TransactionType.expense;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        executeWithContext((ctx) {
          if (!QuickAddTransactionDialog.isOpen) {
            QuickAddTransactionDialog.show(ctx, initialType: initialType);
          }
        });
      });
    }
  }

  void _handleSharedTransaction(UpiParsedTransaction tx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        QuickAddTransactionDialog.show(
          navContext,
          transactionIdToUpdate: tx.id,
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
    final netWorthSummary = ref.read(netWorthSummaryProvider);
    final budgetRemaining = ref.read(totalBudgetRemainingProvider);
    final forecast = ref.read(monthSpendForecastProvider);

    SystemWidgetService.updateWidgetData(
      totalBalance: totalBalance,
      todayExpense: monthlyStats.todayExpense,
      currencySymbol: settings.currencySymbol,
      wallets: wallets,
      statType: settings.homeScreenWidgetStat,
      netWorth: netWorthSummary.totalNetWorth,
      monthlySavings: monthlyStats.netSavings,
      budgetRemaining: budgetRemaining,
      forecast: forecast,
      privacyMode: settings.widgetPrivacyMode,
      selectedWalletId: settings.widgetSelectedWalletId,
      secondaryAction: settings.widgetSecondaryAction,
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
    ref.listen(netWorthSummaryProvider, (prev, next) => _syncWidget());
    ref.listen(categoryBudgetsProvider, (prev, next) => _syncWidget());
    ref.listen(monthSpendForecastProvider, (prev, next) => _syncWidget());

    // Initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWidget());

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
