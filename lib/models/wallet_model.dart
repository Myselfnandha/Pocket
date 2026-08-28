import 'package:flutter/material.dart';

class WalletModel {
  final String id;
  final String name;
  final String icon;
  final int colorValue;
  final double initialBalance;
  final double currentBalance;
  final bool isDefault;

  const WalletModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.initialBalance = 0.0,
    this.currentBalance = 0.0,
    this.isDefault = false,
  });

  Color get color => Color(colorValue);

  WalletModel copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorValue,
    double? initialBalance,
    double? currentBalance,
    bool? isDefault,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorValue': colorValue,
        'initialBalance': initialBalance,
        'currentBalance': currentBalance,
        'isDefault': isDefault,
      };

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        colorValue: json['colorValue'] as int,
        initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

final List<WalletModel> defaultWallets = [
  const WalletModel(
    id: 'cash',
    name: 'Cash',
    icon: '💵',
    colorValue: 0xFF4CAF50,
    initialBalance: 2500.0,
    currentBalance: 2500.0,
    isDefault: true,
  ),
  const WalletModel(
    id: 'bank',
    name: 'Bank Account',
    icon: '🏦',
    colorValue: 0xFF2196F3,
    initialBalance: 25000.0,
    currentBalance: 25000.0,
  ),
  const WalletModel(
    id: 'upi',
    name: 'UPI / Online',
    icon: '📱',
    colorValue: 0xFF9C27B0,
    initialBalance: 5000.0,
    currentBalance: 5000.0,
  ),
];
