import 'package:flutter/material.dart';
import 'category_model.dart';

enum RecurringFrequency { monthly, weekly, yearly }

enum RecurringTemplatePreset {
  rent,
  emi,
  ott,
  electricity,
  phoneBill,
  insurance,
  subscription,
  custom,
}

extension RecurringPresetExtension on RecurringTemplatePreset {
  String get displayName {
    switch (this) {
      case RecurringTemplatePreset.rent:
        return 'House / Flat Rent';
      case RecurringTemplatePreset.emi:
        return 'Loan / EMI Payment';
      case RecurringTemplatePreset.ott:
        return 'OTT Streaming (Netflix, Prime)';
      case RecurringTemplatePreset.electricity:
        return 'Electricity Bill';
      case RecurringTemplatePreset.phoneBill:
        return 'Phone & Internet Bill';
      case RecurringTemplatePreset.insurance:
        return 'Health / Term Insurance';
      case RecurringTemplatePreset.subscription:
        return 'Software / App Subscription';
      case RecurringTemplatePreset.custom:
        return 'Custom Recurring Rule';
    }
  }

  String get defaultIcon {
    switch (this) {
      case RecurringTemplatePreset.rent:
        return '🏠';
      case RecurringTemplatePreset.emi:
        return '💳';
      case RecurringTemplatePreset.ott:
        return '🎬';
      case RecurringTemplatePreset.electricity:
        return '⚡';
      case RecurringTemplatePreset.phoneBill:
        return '📱';
      case RecurringTemplatePreset.insurance:
        return '🛡️';
      case RecurringTemplatePreset.subscription:
        return '📦';
      case RecurringTemplatePreset.custom:
        return '🔄';
    }
  }

  String get suggestedCategory {
    switch (this) {
      case RecurringTemplatePreset.rent:
        return 'rent';
      case RecurringTemplatePreset.emi:
        return 'bills';
      case RecurringTemplatePreset.ott:
        return 'entertainment';
      case RecurringTemplatePreset.electricity:
        return 'bills';
      case RecurringTemplatePreset.phoneBill:
        return 'bills';
      case RecurringTemplatePreset.insurance:
        return 'health';
      case RecurringTemplatePreset.subscription:
        return 'other';
      case RecurringTemplatePreset.custom:
        return 'other';
    }
  }
}

class RecurringRuleModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String walletId;
  final RecurringFrequency frequency;
  final int dueDay; // 1-31 for monthly, 1-7 for weekly
  final DateTime? lastCreatedDate;
  final DateTime nextDueDate;
  final bool isActive;
  final RecurringTemplatePreset templatePreset;
  final String? note;
  final DateTime createdAt;

  const RecurringRuleModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    this.frequency = RecurringFrequency.monthly,
    this.dueDay = 1,
    this.lastCreatedDate,
    required this.nextDueDate,
    this.isActive = true,
    this.templatePreset = RecurringTemplatePreset.custom,
    this.note,
    required this.createdAt,
  });

  RecurringRuleModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    RecurringFrequency? frequency,
    int? dueDay,
    DateTime? lastCreatedDate,
    DateTime? nextDueDate,
    bool? isActive,
    RecurringTemplatePreset? templatePreset,
    String? note,
    DateTime? createdAt,
  }) {
    return RecurringRuleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      dueDay: dueDay ?? this.dueDay,
      lastCreatedDate: lastCreatedDate ?? this.lastCreatedDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isActive: isActive ?? this.isActive,
      templatePreset: templatePreset ?? this.templatePreset,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'categoryId': categoryId,
        'walletId': walletId,
        'frequency': frequency.name,
        'dueDay': dueDay,
        'lastCreatedDate': lastCreatedDate?.toIso8601String(),
        'nextDueDate': nextDueDate.toIso8601String(),
        'isActive': isActive,
        'templatePreset': templatePreset.name,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecurringRuleModel.fromJson(Map<String, dynamic> json) =>
      RecurringRuleModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: TransactionType.values.byName(
          json['type'] as String? ?? 'expense',
        ),
        categoryId: json['categoryId'] as String,
        walletId: json['walletId'] as String,
        frequency: RecurringFrequency.values.byName(
          json['frequency'] as String? ?? 'monthly',
        ),
        dueDay: json['dueDay'] as int? ?? 1,
        lastCreatedDate: json['lastCreatedDate'] != null
            ? DateTime.parse(json['lastCreatedDate'] as String)
            : null,
        nextDueDate: DateTime.parse(json['nextDueDate'] as String),
        isActive: json['isActive'] as bool? ?? true,
        templatePreset: RecurringTemplatePreset.values.byName(
          json['templatePreset'] as String? ?? 'custom',
        ),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  DateTime calculateNextDueDateAfter(DateTime fromDate) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        int nextYear = fromDate.year;
        int nextMonth = fromDate.month + 1;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final daysInNextMonth = DateUtils.getDaysInMonth(nextYear, nextMonth);
        final safeDay = dueDay.clamp(1, daysInNextMonth);
        return DateTime(nextYear, nextMonth, safeDay, fromDate.hour, fromDate.minute);
      case RecurringFrequency.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
  }
}
