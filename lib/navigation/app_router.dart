import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../screens/home/home_screen.dart';
import '../screens/transactions/transactions_list_screen.dart';
import '../screens/transactions/add_transaction_screen.dart';
import '../screens/transactions/transaction_detail_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/wallets/wallets_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/recurring_rules_screen.dart';
import '../screens/settings/data_management_screen.dart';
import '../screens/notifications/notification_center_screen.dart';
import '../screens/debts/debts_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import 'app_scaffold.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(bool isOnboarded) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: isOnboarded ? '/home' : '/onboarding',
    errorBuilder: (context, state) => const HomeScreen(),
    routes: [
      // Root Redirect Route (Fixes deep links sending '/' or '/?')
      GoRoute(
        path: '/',
        redirect: (context, state) => isOnboarded ? '/home' : '/onboarding',
      ),

      // Onboarding Route
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Add Transaction (Full Screen Modal with Pre-fill Support)
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return AddTransactionScreen(
              initialAmount: extra['amount'] as double?,
              initialTitle: extra['title'] as String?,
              initialType: extra['type'] as TransactionType?,
              initialCategoryId: extra['categoryId'] as String?,
              initialWalletId: extra['walletId'] as String?,
              initialNote: extra['note'] as String?,
              initialReceiptImagePath: extra['receiptImagePath'] as String?,
            );
          }
          return const AddTransactionScreen();
        },
      ),

      // Full Transactions List (Dedicated Screen)
      GoRoute(
        path: '/transactions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TransactionsListScreen(),
      ),

      // Settings (Dedicated Screen)
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Recurring Rules (Dedicated Screen)
      GoRoute(
        path: '/recurring-rules',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RecurringRulesScreen(),
      ),

      // Notification Center (Dedicated Screen)
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationCenterScreen(),
      ),

      // Data & Account Management (Dedicated Screen)
      GoRoute(
        path: '/data-management',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DataManagementScreen(),
      ),

      // Debts & Loans (Dedicated Screen)
      GoRoute(
        path: '/debts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DebtsScreen(),
      ),

      // Transaction Detail
      GoRoute(
        path: '/transaction-detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is TransactionModel) {
            return TransactionDetailScreen(transaction: extra);
          }
          // Safe fallback if navigated without extra
          return const HomeScreen();
        },
      ),

      // 3-Tab Navigation Shell: Home, Analytics, Wallets
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 2: Analytics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),

          // Tab 3: Wallets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallets',
                builder: (context, state) => const WalletsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
