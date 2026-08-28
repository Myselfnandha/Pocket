class CategoryBudgetModel {
  final String id;
  final String categoryId;
  final double monthlyLimit;
  final bool isRolloverEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryBudgetModel({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    this.isRolloverEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryBudgetModel copyWith({
    String? id,
    String? categoryId,
    double? monthlyLimit,
    bool? isRolloverEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryBudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      isRolloverEnabled: isRolloverEnabled ?? this.isRolloverEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates safe daily spending allowance for the remainder of the month
  double calculateDailySafeSpend(double currentSpent, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (totalDaysInMonth - now.day + 1).clamp(1, totalDaysInMonth);
    final remainingBudget = monthlyLimit - currentSpent;
    if (remainingBudget <= 0) return 0.0;
    return remainingBudget / remainingDays;
  }

  /// Calculates progress percentage clamped between 0.0 and 1.0 (or > 1.0 for overflow)
  double calculateProgress(double currentSpent) {
    if (monthlyLimit <= 0) return 1.0;
    return (currentSpent / monthlyLimit).clamp(0.0, 2.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'monthlyLimit': monthlyLimit,
        'isRolloverEnabled': isRolloverEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CategoryBudgetModel.fromJson(Map<String, dynamic> json) =>
      CategoryBudgetModel(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 0.0,
        isRolloverEnabled: json['isRolloverEnabled'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}
