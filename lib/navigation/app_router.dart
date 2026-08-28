import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction_model.dart';
import '../screens/home/home_screen.dart';
import '../screens/transactions/transactions_list_screen.dart';
import '../screens/transactions/add_transaction_screen.dart';
import '../screens/transactions/transaction_detail_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/wallets/wallets_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import 'app_scaffold.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(bool isOnboarded) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: isOnboarded ? '/home' : '/onboarding',
    routes: [
      // Onboarding Route
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Add Transaction (Full Screen Modal)
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddTransactionScreen(),
      ),

      // Full Transactions List (Dedicated Screen)
      GoRoute(
        path: '/transactions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TransactionsListScreen(),
      ),

      // Settings (Dedicated Screen)
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Transaction Detail
      GoRoute(
        path: '/transaction-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final tx = state.extra as TransactionModel;
          return TransactionDetailScreen(transaction: tx);
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
