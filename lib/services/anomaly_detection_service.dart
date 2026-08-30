import 'dart:math';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

class AnomalyResult {
  final bool isAnomaly;
  final double enteredAmount;
  final double categoryAverage;
  final double multipleOfAverage;
  final double zScore;
  final String categoryName;
  final String message;

  const AnomalyResult({
    required this.isAnomaly,
    required this.enteredAmount,
    required this.categoryAverage,
    required this.multipleOfAverage,
    required this.zScore,
    required this.categoryName,
    required this.message,
  });

  factory AnomalyResult.normal() => const AnomalyResult(
        isAnomaly: false,
        enteredAmount: 0,
        categoryAverage: 0,
        multipleOfAverage: 1.0,
        zScore: 0,
        categoryName: '',
        message: '',
      );
}

class AnomalyDetectionService {
  /// Evaluates whether an entered transaction amount is an anomaly for its category
  static AnomalyResult checkAnomaly({
    required double amount,
    required String categoryId,
    required List<TransactionModel> pastTransactions,
    required List<CategoryModel> categories,
    String currencySymbol = '₹',
  }) {
    if (amount <= 0) return AnomalyResult.normal();

    // Filter past expenses for this category
    final categoryTxs = pastTransactions
        .where((t) => t.categoryId == categoryId && t.type == TransactionType.expense && t.amount > 0)
        .toList();

    final category = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const CategoryModel(id: '', name: 'this category', icon: '🏷️', colorValue: 0),
    );

    // Need at least 3 historical data points for meaningful statistical comparison
    if (categoryTxs.length < 3) {
      return AnomalyResult.normal();
    }

    final amounts = categoryTxs.map((t) => t.amount).toList();
    final double sum = amounts.reduce((a, b) => a + b);
    final double mean = sum / amounts.length;

    // Variance & standard deviation
    double varianceSum = 0.0;
    for (final a in amounts) {
      varianceSum += pow(a - mean, 2);
    }
    final double stdDev = sqrt(varianceSum / (amounts.length - 1));

    final double multiple = amount / max(1.0, mean);
    final double zScore = stdDev > 0 ? (amount - mean) / stdDev : multiple;

    // Thresholds: amount is 3.5x higher than average OR z-score >= 3.0 & multiple >= 2.5 with min amount
    final bool isAnomaly = (multiple >= 3.5 && amount >= 1000) || (zScore >= 3.0 && multiple >= 2.5 && amount >= 1000);

    if (isAnomaly) {
      final multipleFormatted = multiple.toStringAsFixed(1).replaceAll('.0', '');
      final avgFormatted = '$currencySymbol${mean.toStringAsFixed(0)}';
      final enteredFormatted = '$currencySymbol${amount.toStringAsFixed(0)}';

      final message = 'Unusually large entry: $enteredFormatted is ${multipleFormatted}x higher than your usual $avgFormatted average for ${category.name}. Check amount or confirm.';

      return AnomalyResult(
        isAnomaly: true,
        enteredAmount: amount,
        categoryAverage: mean,
        multipleOfAverage: multiple,
        zScore: zScore,
        categoryName: category.name,
        message: message,
      );
    }

    return AnomalyResult.normal();
  }
}
