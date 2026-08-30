import 'package:flutter/material.dart';

class GoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double currentSavedAmount;
  final DateTime? targetDate;
  final String? walletId;
  final String emojiIcon;
  final int colorValue;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentSavedAmount = 0.0,
    this.targetDate,
    this.walletId,
    this.emojiIcon = '🎯',
    this.colorValue = 0xFF00E676,
    required this.createdAt,
  });

  double get progress => targetAmount > 0 ? (currentSavedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remainingAmount => (targetAmount - currentSavedAmount).clamp(0.0, double.infinity);
  bool get isCompleted => currentSavedAmount >= targetAmount && targetAmount > 0;

  int? get daysRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final difference = targetDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
    return difference >= 0 ? difference : 0;
  }

  Color get color => Color(colorValue);

  GoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentSavedAmount,
    DateTime? targetDate,
    String? walletId,
    String? emojiIcon,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentSavedAmount: currentSavedAmount ?? this.currentSavedAmount,
      targetDate: targetDate ?? this.targetDate,
      walletId: walletId ?? this.walletId,
      emojiIcon: emojiIcon ?? this.emojiIcon,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'currentSavedAmount': currentSavedAmount,
        'targetDate': targetDate?.toIso8601String(),
        'walletId': walletId,
        'emojiIcon': emojiIcon,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Goal',
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
        currentSavedAmount: (json['currentSavedAmount'] as num?)?.toDouble() ?? 0.0,
        targetDate: json['targetDate'] != null ? DateTime.tryParse(json['targetDate'] as String) : null,
        walletId: json['walletId'] as String?,
        emojiIcon: json['emojiIcon'] as String? ?? '🎯',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF00E676,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
