import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/wallet_model.dart';
import '../models/settings_model.dart';
import 'ai_forecasting_service.dart';

class SystemWidgetService {
  static const String androidWidgetName = 'PocketWidgetProvider';
  static StreamSubscription<Uri?>? _widgetSubscription;

  /// Updates all Android System Home Screen Widgets with configurable stats, privacy masking & runway
  static Future<void> updateWidgetData({
    required double totalBalance,
    required double todayExpense,
    required String currencySymbol,
    List<WalletModel>? wallets,
    HomeScreenWidgetStat statType = HomeScreenWidgetStat.balanceAndTodaySpend,
    double? netWorth,
    double? monthlySavings,
    double? budgetRemaining,
    MonthSpendForecast? forecast,
    bool privacyMode = false,
    String? selectedWalletId,
    String secondaryAction = 'scan',
  }) async {
    try {
      final currencyFormat = NumberFormat('#,##0.00');

      // 1. Resolve Account & Balance for Card Widget
      double cardBalance = totalBalance;
      String walletLabel = 'All Accounts';
      if (selectedWalletId != null && wallets != null && wallets.isNotEmpty) {
        final matched = wallets.where((w) => w.id == selectedWalletId);
        if (matched.isNotEmpty) {
          cardBalance = matched.first.currentBalance;
          walletLabel = matched.first.name;
        }
      }

      final formattedCardRaw = '$currencySymbol${currencyFormat.format(cardBalance)}';
      final formattedTotalRaw = '$currencySymbol${currencyFormat.format(totalBalance)}';

      final formattedCard = privacyMode ? '••••••' : formattedCardRaw;
      final formattedTotal = privacyMode ? '••••••' : formattedTotalRaw;
      final formattedToday = '$currencySymbol${currencyFormat.format(todayExpense)} Today';
      final formattedDate = DateFormat('d MMM').format(DateTime.now());

      // 2. Resolve Safe-to-Spend Runway Daily Allowance
      int daysLeft = 1;
      double safeDaily = 0.0;
      String statusTag = '✓ ON TRACK';
      String budgetLeftDesc = 'No active budget';

      final isOverBudget = budgetRemaining != null && budgetRemaining <= 0;
      final isNearBudget = budgetRemaining != null && budgetRemaining > 0 && budgetRemaining < (forecast?.currentDailyBurnRate ?? 100) * 3;

      if (forecast != null && budgetRemaining != null) {
        daysLeft = forecast.daysRemainingInMonth > 0 ? forecast.daysRemainingInMonth : 1;
        safeDaily = (budgetRemaining > 0 ? budgetRemaining : 0.0) / daysLeft;
        statusTag = isOverBudget
            ? '⚠️ OVER BUDGET'
            : (isNearBudget ? '⚡ NEARING LIMIT' : '✓ ON TRACK');
        budgetLeftDesc = '$currencySymbol${currencyFormat.format(budgetRemaining)} left of budget';
      } else {
        daysLeft = 30 - DateTime.now().day + 1;
        if (daysLeft < 1) daysLeft = 1;
        safeDaily = (totalBalance > 0 ? totalBalance : 0.0) / daysLeft;
        statusTag = '✓ HEALTHY';
        budgetLeftDesc = 'Net balance: $formattedTotalRaw';
      }

      final runwaySafeFormatted = privacyMode ? '••••••' : '$currencySymbol${currencyFormat.format(safeDaily)}';
      final budgetTag = isOverBudget
          ? 'Over Budget'
          : (isNearBudget ? 'Nearing Limit' : 'On Budget');

      // 3. Accounts Summary
      String accountsSummary = 'No accounts created';
      if (wallets != null && wallets.isNotEmpty) {
        accountsSummary = wallets.map((w) {
          final last4 = w.maskedAccountNumber.isNotEmpty ? ' (${w.maskedAccountNumber})' : '';
          final bal = privacyMode ? '••••' : '$currencySymbol${currencyFormat.format(w.currentBalance)}';
          return '${w.icon} ${w.name}$last4: $bal';
        }).join('  •  ');
      }

      String sparklineData = '';
      if (forecast != null && forecast.sparklineValues.isNotEmpty) {
        sparklineData = forecast.sparklineValues.map((v) => v.toStringAsFixed(0)).join(',');
      }

      // 4. Save to Android SharedPreferences via HomeWidget
      await HomeWidget.saveWidgetData<String>('total_balance', formattedTotal);
      await HomeWidget.saveWidgetData<String>('card_balance', formattedCard);
      await HomeWidget.saveWidgetData<String>('card_wallet_name', walletLabel);
      await HomeWidget.saveWidgetData<String>('today_expense', formattedToday);
      await HomeWidget.saveWidgetData<String>('budget_status_tag', budgetTag);
      await HomeWidget.saveWidgetData<String>('secondary_action_type', secondaryAction);
      await HomeWidget.saveWidgetData<String>('runway_safe_daily', runwaySafeFormatted);
      await HomeWidget.saveWidgetData<String>('runway_days_left', '${daysLeft}d left');
      await HomeWidget.saveWidgetData<String>('runway_status', statusTag);
      await HomeWidget.saveWidgetData<String>('runway_budget_left', budgetLeftDesc);
      await HomeWidget.saveWidgetData<String>('current_date', formattedDate);
      await HomeWidget.saveWidgetData<String>('accounts_summary', accountsSummary);
      await HomeWidget.saveWidgetData<String>('forecast_sparkline', sparklineData);

      // 5. Update All Registered Widget Providers
      for (final provider in [
        'PocketWidgetProvider',
        'PocketCardWidgetProvider',
        'PocketRunwayWidgetProvider',
        'PocketBarWidgetProvider',
      ]) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
          qualifiedAndroidName: 'com.pocket.pocket.$provider',
        );
      }
    } catch (e) {
      debugPrint('SystemWidgetService update error: $e');
    }
  }

  /// Clears & resets Android Home Screen Widgets to zero-state (₹0.00 / No active accounts)
  static Future<void> clearWidgetData([String currencySymbol = '₹']) async {
    try {
      final formattedDate = DateFormat('d MMM').format(DateTime.now());
      await HomeWidget.saveWidgetData<String>('total_balance', '${currencySymbol}0.00');
      await HomeWidget.saveWidgetData<String>('card_balance', '${currencySymbol}0.00');
      await HomeWidget.saveWidgetData<String>('card_wallet_name', 'Main Account');
      await HomeWidget.saveWidgetData<String>('today_expense', '${currencySymbol}0.00 Today');
      await HomeWidget.saveWidgetData<String>('budget_status_tag', 'On Budget');
      await HomeWidget.saveWidgetData<String>('secondary_action_type', 'scan');
      await HomeWidget.saveWidgetData<String>('runway_safe_daily', '${currencySymbol}0.00');
      await HomeWidget.saveWidgetData<String>('runway_days_left', '0d left');
      await HomeWidget.saveWidgetData<String>('runway_status', '✓ ON TRACK');
      await HomeWidget.saveWidgetData<String>('runway_budget_left', 'No active budget');
      await HomeWidget.saveWidgetData<String>('current_date', formattedDate);
      await HomeWidget.saveWidgetData<String>('accounts_summary', 'No active accounts');

      for (final provider in [
        'PocketWidgetProvider',
        'PocketCardWidgetProvider',
        'PocketRunwayWidgetProvider',
        'PocketBarWidgetProvider',
      ]) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
          qualifiedAndroidName: 'com.pocket.pocket.$provider',
        );
      }
    } catch (e) {
      debugPrint('SystemWidgetService clearWidgetData error: $e');
    }
  }

  static const MethodChannel _nativeChannel = MethodChannel('com.pocket.pocket/widget_events');

  /// Request system launcher to pin a widget to phone desktop
  static Future<bool> requestPinWidget(String widgetType) async {
    try {
      final success = await _nativeChannel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error requesting widget pin: $e');
      return false;
    }
  }

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
