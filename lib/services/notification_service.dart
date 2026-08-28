import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_model.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    _initialized = true;
  }

  // Request notifications permission (Android 13+)
  Future<bool?> requestPermissions() async {
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.requestNotificationsPermission();
      }
    } catch (_) {}
    return true;
  }

  // Show immediate local notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'pocket_channel_id',
      'Pocket Alerts',
      channelDescription: 'Financial updates, reminders, and budget warnings',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } catch (_) {}
  }

  // Schedule daily spending reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    if (!enabled) {
      await _flutterLocalNotificationsPlugin.cancel(1001);
      return;
    }

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        1001,
        'Daily Spending Check-in 🌿',
        "Don't forget to log your daily expenses in Pocket!",
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pocket_reminders_channel',
            'Daily Reminders',
            channelDescription: 'Daily evening reminder to log transactions',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  // Check budget limits and trigger warnings if necessary
  Future<void> checkBudgetThresholds({
    required StorageService storage,
    required double totalExpenseThisMonth,
    required double totalIncomeThisMonth,
  }) async {
    final settings = storage.getSettings();
    final wallets = storage.getWallets();

    // Check individual wallet limits
    for (final wallet in wallets) {
      if (wallet.spendingLimit != null && wallet.spendingLimit! > 0) {
        final limit = wallet.spendingLimit!;
        final txs = storage.getTransactions();
        final now = DateTime.now();

        double walletExpense = 0;
        for (final tx in txs) {
          if (tx.walletId == wallet.id &&
              tx.date.year == now.year &&
              tx.date.month == now.month) {
            walletExpense += tx.amount;
          }
        }

        if (walletExpense >= limit && settings.notifyBudgetExceeded) {
          final notif = AppNotificationModel(
            id: 'wallet_exceeded_${wallet.id}_${now.month}',
            title: 'Budget Exceeded: ${wallet.name}',
            message: 'You have spent ${settings.currencySymbol}${walletExpense.toStringAsFixed(2)} exceeding your limit of ${settings.currencySymbol}${limit.toStringAsFixed(2)}.',
            type: NotificationType.budgetExceeded,
            createdAt: now,
          );
          await storage.addNotification(notif);
          await showNotification(
            id: wallet.hashCode.abs() % 100000,
            title: notif.title,
            body: notif.message,
            type: NotificationType.budgetExceeded,
          );
        } else if (walletExpense >= (limit * 0.8) && settings.notifyBudgetNearLimit) {
          final notif = AppNotificationModel(
            id: 'wallet_near_limit_${wallet.id}_${now.month}',
            title: 'Budget Warning: ${wallet.name} (80%)',
            message: 'You have reached 80% of your ${wallet.name} budget limit.',
            type: NotificationType.budgetNearLimit,
            createdAt: now,
          );
          await storage.addNotification(notif);
          await showNotification(
            id: wallet.hashCode.abs() % 100000 + 1,
            title: notif.title,
            body: notif.message,
            type: NotificationType.budgetNearLimit,
          );
        }
      }
    }
  }
}
