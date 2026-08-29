import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class SystemWidgetService {
  static const String androidWidgetName = 'PocketWidgetProvider';
  static StreamSubscription<Uri?>? _widgetSubscription;

  /// Updates the Android System Home Screen App Widget with real-time balance and today's spend
  static Future<void> updateWidgetData({
    required double totalBalance,
    required double todayExpense,
    required String currencySymbol,
  }) async {
    try {
      final currencyFormat = NumberFormat('#,##0.00');
      final formattedBalance = '$currencySymbol${currencyFormat.format(totalBalance)}';
      final formattedExpense = '$currencySymbol${currencyFormat.format(todayExpense)}';
      final formattedDate = DateFormat('d MMM').format(DateTime.now());

      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>('today_expense', formattedExpense);
      await HomeWidget.saveWidgetData<String>('current_date', formattedDate);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.pocket.pocket.PocketWidgetProvider',
      );
    } catch (e) {
      debugPrint('SystemWidgetService update error: $e');
    }
  }

  /// Listens for quick action deep links triggered from the Android system home screen widget
  static void registerWidgetLaunchCallback(Function(Uri uri) onLaunchUri) {
    // Check initial launch
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        onLaunchUri(uri);
      }
    });

    // Listen to foreground/background launches
    _widgetSubscription?.cancel();
    _widgetSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        onLaunchUri(uri);
      }
    });
  }

  static void dispose() {
    _widgetSubscription?.cancel();
  }
}
