import 'dart:math';

class InflationComparisonResult {
  final double originalAmount;
  final DateTime historicalDate;
  final DateTime targetDate;
  final double equivalentAmountToday;
  final double purchasingPowerLossPercent;
  final double annualizedInflationRate;
  final double yearDifference;

  const InflationComparisonResult({
    required this.originalAmount,
    required this.historicalDate,
    required this.targetDate,
    required this.equivalentAmountToday,
    required this.purchasingPowerLossPercent,
    required this.annualizedInflationRate,
    required this.yearDifference,
  });
}

class InflationService {
  static const double defaultAnnualInflationRate = 0.06; // 6% annual CPI baseline

  /// Computes the inflation-adjusted equivalent amount today
  /// Formula: FutureValue = PastValue * (1 + r)^t
  static InflationComparisonResult calculatePurchasingPower({
    required double pastAmount,
    required DateTime pastDate,
    DateTime? today,
    double annualInflationRate = defaultAnnualInflationRate,
  }) {
    final now = today ?? DateTime.now();
    final daysDifference = max(0, now.difference(pastDate).inDays);
    final double years = daysDifference / 365.25;

    if (years <= 0 || pastAmount <= 0) {
      return InflationComparisonResult(
        originalAmount: pastAmount,
        historicalDate: pastDate,
        targetDate: now,
        equivalentAmountToday: pastAmount,
        purchasingPowerLossPercent: 0.0,
        annualizedInflationRate: annualInflationRate,
        yearDifference: 0.0,
      );
    }

    final double compoundFactor = pow(1.0 + annualInflationRate, years).toDouble();
    final double equivalentToday = pastAmount * compoundFactor;
    final double realPurchasingPowerToday = pastAmount / compoundFactor;
    final double powerLossPercent = ((pastAmount - realPurchasingPowerToday) / pastAmount) * 100;

    return InflationComparisonResult(
      originalAmount: pastAmount,
      historicalDate: pastDate,
      targetDate: now,
      equivalentAmountToday: equivalentToday,
      purchasingPowerLossPercent: powerLossPercent.clamp(0.0, 99.9),
      annualizedInflationRate: annualInflationRate,
      yearDifference: years,
    );
  }
}
