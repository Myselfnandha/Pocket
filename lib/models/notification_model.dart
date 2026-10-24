import 'package:flutter/material.dart';

enum NotificationType {
  budgetNearLimit,
  budgetExceeded,
  recurringDue,
  recurringCreated,
  dailyReminder,
  monthlySummary,
  system,
  autoLogged,
}

extension NotificationTypeExt on NotificationType {
  String get defaultTitle {
    switch (this) {
      case NotificationType.budgetNearLimit:
        return 'Budget Warning (80% Reached)';
      case NotificationType.budgetExceeded:
        return 'Budget Exceeded Alert!';
      case NotificationType.recurringDue:
        return 'Recurring Payment Due';
      case NotificationType.recurringCreated:
        return 'Recurring Transaction Logged';
      case NotificationType.dailyReminder:
        return 'Daily Spending Check-in';
      case NotificationType.monthlySummary:
        return 'Monthly Financial Summary';
      case NotificationType.system:
        return 'Pocket System Notice';
      case NotificationType.autoLogged:
        return 'Auto-Logged Transaction';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.budgetNearLimit:
        return Icons.warning_amber_rounded;
      case NotificationType.budgetExceeded:
        return Icons.error_outline_rounded;
      case NotificationType.recurringDue:
        return Icons.alarm_rounded;
      case NotificationType.recurringCreated:
        return Icons.autorenew_rounded;
      case NotificationType.dailyReminder:
        return Icons.today_rounded;
      case NotificationType.monthlySummary:
        return Icons.assessment_outlined;
      case NotificationType.system:
        return Icons.info_outline_rounded;
      case NotificationType.autoLogged:
        return Icons.bolt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.budgetNearLimit:
        return const Color(0xFFFF9800);
      case NotificationType.budgetExceeded:
        return const Color(0xFFEF5350);
      case NotificationType.recurringDue:
        return const Color(0xFF29B6F6);
      case NotificationType.recurringCreated:
        return const Color(0xFF4CAF50);
      case NotificationType.dailyReminder:
        return const Color(0xFF9C27B0);
      case NotificationType.monthlySummary:
        return const Color(0xFF4CAF50);
      case NotificationType.system:
        return const Color(0xFF2E7D32);
      case NotificationType.autoLogged:
        return const Color(0xFF00E676);
    }
  }
}

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? actionData;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionData,
  });

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? actionData,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionData: actionData ?? this.actionData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'actionData': actionData,
      };

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String? ?? 'notif_${DateTime.now().microsecondsSinceEpoch}',
        title: json['title'] as String? ?? 'Notification',
        message: json['message'] as String? ?? '',
        type: NotificationType.values.asNameMap()[json['type']] ?? NotificationType.system,
        createdAt: json['createdAt'] != null
            ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
            : DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
        actionData: json['actionData'] as Map<String, dynamic>?,
      );
}
