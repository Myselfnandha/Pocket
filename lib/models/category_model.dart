import 'package:flutter/material.dart';

enum TransactionType { expense, income }

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final int colorValue;
  final TransactionType type;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.type = TransactionType.expense,
    this.isDefault = true,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorValue,
    TransactionType? type,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorValue': colorValue,
        'type': type.name,
        'isDefault': isDefault,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        colorValue: json['colorValue'] as int,
        type: TransactionType.values.byName(json['type'] as String? ?? 'expense'),
        isDefault: json['isDefault'] as bool? ?? true,
      );
}

final List<CategoryModel> defaultCategories = [
  // Expenses
  const CategoryModel(
    id: 'food',
    name: 'Food & Dining',
    icon: '🍔',
    colorValue: 0xFFEF5350,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'transport',
    name: 'Transport',
    icon: '🚗',
    colorValue: 0xFF42A5F5,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'rent',
    name: 'Rent & Housing',
    icon: '🏠',
    colorValue: 0xFF26A69A,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'groceries',
    name: 'Groceries',
    icon: '🛒',
    colorValue: 0xFFFF9800,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'health',
    name: 'Health & Medical',
    icon: '💊',
    colorValue: 0xFFEC407A,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'entertainment',
    name: 'Entertainment',
    icon: '🎬',
    colorValue: 0xFFAB47BC,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'shopping',
    name: 'Shopping',
    icon: '👕',
    colorValue: 0xFF5C6BC0,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'utilities',
    name: 'Bills & Utilities',
    icon: '⚡',
    colorValue: 0xFFFFCA28,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'travel',
    name: 'Travel',
    icon: '✈️',
    colorValue: 0xFF29B6F6,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'education',
    name: 'Education',
    icon: '📚',
    colorValue: 0xFF7E57C2,
    type: TransactionType.expense,
  ),
  const CategoryModel(
    id: 'other_exp',
    name: 'Other Expense',
    icon: '📦',
    colorValue: 0xFF8D6E63,
    type: TransactionType.expense,
  ),

  // Income
  const CategoryModel(
    id: 'salary',
    name: 'Salary',
    icon: '💰',
    colorValue: 0xFF4CAF50,
    type: TransactionType.income,
  ),
  const CategoryModel(
    id: 'freelance',
    name: 'Freelance & Business',
    icon: '💼',
    colorValue: 0xFF66BB6A,
    type: TransactionType.income,
  ),
  const CategoryModel(
    id: 'investments',
    name: 'Investments',
    icon: '📈',
    colorValue: 0xFF26C6DA,
    type: TransactionType.income,
  ),
  const CategoryModel(
    id: 'gifts',
    name: 'Gifts & Awards',
    icon: '🎁',
    colorValue: 0xFFFF7043,
    type: TransactionType.income,
  ),
  const CategoryModel(
    id: 'other_inc',
    name: 'Other Income',
    icon: '💵',
    colorValue: 0xFF81C784,
    type: TransactionType.income,
  ),
];
