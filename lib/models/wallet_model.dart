import 'package:flutter/material.dart';

enum WalletType { cash, bank, upi, creditCard, savings }

class WalletModel {
  final String id;
  final String name;
  final String icon;
  final int colorValue;
  final double initialBalance;
  final double currentBalance;
  final WalletType walletType;
  final double? spendingLimit;
  final bool isDefault;
  final String? accountNumber; // Last 4 digits e.g. "4821"

  const WalletModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.initialBalance = 0.0,
    this.currentBalance = 0.0,
    this.walletType = WalletType.bank,
    this.spendingLimit,
    this.isDefault = false,
    this.accountNumber,
  });

  Color get color => Color(colorValue);

  String get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.trim().isEmpty) return '';
    final digits = accountNumber!.trim();
    return digits.length <= 4 ? '•••• $digits' : '•••• ${digits.substring(digits.length - 4)}';
  }

  WalletModel copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorValue,
    double? initialBalance,
    double? currentBalance,
    WalletType? walletType,
    double? spendingLimit,
    bool? isDefault,
    String? accountNumber,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      walletType: walletType ?? this.walletType,
      spendingLimit: spendingLimit ?? this.spendingLimit,
      isDefault: isDefault ?? this.isDefault,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorValue': colorValue,
        'initialBalance': initialBalance,
        'currentBalance': currentBalance,
        'walletType': walletType.name,
        'spendingLimit': spendingLimit,
        'isDefault': isDefault,
        'accountNumber': accountNumber,
      };

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        colorValue: json['colorValue'] as int,
        initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
        walletType: WalletType.values.byName(
          json['walletType'] as String? ?? 'bank',
        ),
        spendingLimit: (json['spendingLimit'] as num?)?.toDouble(),
        isDefault: json['isDefault'] as bool? ?? false,
        accountNumber: json['accountNumber'] as String?,
      );
}

final List<WalletModel> defaultWallets = [
  const WalletModel(
    id: 'cash',
    name: 'Cash',
    icon: '💵',
    colorValue: 0xFF4CAF50,
    initialBalance: 0.0,
    currentBalance: 0.0,
    walletType: WalletType.cash,
    isDefault: true,
  ),
  const WalletModel(
    id: 'bank',
    name: 'Bank Account',
    icon: '🏦',
    colorValue: 0xFF2196F3,
    initialBalance: 0.0,
    currentBalance: 0.0,
    walletType: WalletType.bank,
  ),
  const WalletModel(
    id: 'upi',
    name: 'UPI / Online',
    icon: '📱',
    colorValue: 0xFF9C27B0,
    initialBalance: 0.0,
    currentBalance: 0.0,
    walletType: WalletType.upi,
  ),
];
