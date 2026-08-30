import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/wallet_model.dart';
import '../models/settings_model.dart';

class SystemWidgetService {
  static const String androidWidgetName = 'PocketWidgetProvider';
  static StreamSubscription<Uri?>? _widgetSubscription;

  /// Updates the Android System Home Screen App Widget with configurable stats
  static Future<void> updateWidgetData({
    required double totalBalance,
    required double todayExpense,
    required String currencySymbol,
    List<WalletModel>? wallets,
    HomeScreenWidgetStat statType = HomeScreenWidgetStat.balanceAndTodaySpend,
    double? netWorth,
    double? monthlySavings,
    double? budgetRemaining,
  }) async {
    try {
      final currencyFormat = NumberFormat('#,##0.00');
      String formattedPrimary = '$currencySymbol${currencyFormat.format(totalBalance)}';
      String formattedSecondary = '$currencySymbol${currencyFormat.format(todayExpense)}';
      final formattedDate = DateFormat('d MMM').format(DateTime.now());

      switch (statType) {
        case HomeScreenWidgetStat.netWorth:
          if (netWorth != null) {
            formattedPrimary = '$currencySymbol${currencyFormat.format(netWorth)}';
            formattedSecondary = 'Net Worth';
          }
          break;
        case HomeScreenWidgetStat.monthlySavings:
          if (monthlySavings != null) {
            formattedSecondary = '${monthlySavings >= 0 ? '+' : '-'}$currencySymbol${currencyFormat.format(monthlySavings.abs())} Saved';
          }
          break;
        case HomeScreenWidgetStat.budgetRemaining:
          if (budgetRemaining != null) {
            formattedSecondary = '$currencySymbol${currencyFormat.format(budgetRemaining)} Left';
          }
          break;
        case HomeScreenWidgetStat.debtsSummary:
        case HomeScreenWidgetStat.balanceAndTodaySpend:
          break;
      }

      String accountsSummary = 'No accounts created';
      if (wallets != null && wallets.isNotEmpty) {
        accountsSummary = wallets.map((w) {
          final last4 = w.maskedAccountNumber.isNotEmpty ? ' (${w.maskedAccountNumber})' : '';
          return '${w.icon} ${w.name}$last4: $currencySymbol${currencyFormat.format(w.currentBalance)}';
        }).join('  •  ');
      }

      await HomeWidget.saveWidgetData<String>('total_balance', formattedPrimary);
      await HomeWidget.saveWidgetData<String>('today_expense', formattedSecondary);
      await HomeWidget.saveWidgetData<String>('current_date', formattedDate);
      await HomeWidget.saveWidgetData<String>('accounts_summary', accountsSummary);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.pocket.pocket.PocketWidgetProvider',
      );
    } catch (e) {
      debugPrint('SystemWidgetService update error: $e');
    }
  }

  /// Clears & resets Android Home Screen Widget to zero-state (₹0.00 / No active accounts)
  static Future<void> clearWidgetData([String currencySymbol = '₹']) async {
    try {
      final formattedDate = DateFormat('d MMM').format(DateTime.now());
      await HomeWidget.saveWidgetData<String>('total_balance', '${currencySymbol}0.00');
      await HomeWidget.saveWidgetData<String>('today_expense', '${currencySymbol}0.00');
      await HomeWidget.saveWidgetData<String>('current_date', formattedDate);
      await HomeWidget.saveWidgetData<String>('accounts_summary', 'No active accounts');

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.pocket.pocket.PocketWidgetProvider',
      );
    } catch (e) {
      debugPrint('SystemWidgetService clearWidgetData error: $e');
    }
  }

  static const MethodChannel _nativeChannel = MethodChannel('com.pocket.pocket/widget_events');

  /// Listens for quick action deep links triggered from the Android system home screen widget
  static void registerWidgetLaunchCallback(Function(Uri uri) onLaunchUri) {
    // 1. Check initial launch via HomeWidget plugin
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        onLaunchUri(uri);
      }
    });

    // 2. Listen to foreground/background launches via HomeWidget stream
    _widgetSubscription?.cancel();
    _widgetSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        onLaunchUri(uri);
      }
    });

    // 3. Listen to native Android Intent channel directly (instant fallback)
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetUriReceived') {
        final uriStr = call.arguments as String?;
        if (uriStr != null) {
          final uri = Uri.tryParse(uriStr);
          if (uri != null) {
            onLaunchUri(uri);
          }
        }
      }
    });

    // 4. Check if native channel has a pending widget uri
    _nativeChannel.invokeMethod<String>('getPendingWidgetUri').then((uriStr) {
      if (uriStr != null) {
        final uri = Uri.tryParse(uriStr);
        if (uri != null) {
          onLaunchUri(uri);
        }
      }
    });
  }

  static void dispose() {
    _widgetSubscription?.cancel();
  }
}
