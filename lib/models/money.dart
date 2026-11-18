import 'package:intl/intl.dart';

/// Immutable Value Object representing financial amounts in exact integer minor units (e.g. paise for INR).
/// Eliminates IEEE-754 binary floating-point drift while providing safe conversions and formatting.
class Money implements Comparable<Money> {
  /// The amount in minor currency units (paise for INR, cents for USD).
  final int minorUnits;

  /// ISO 4217 Currency Code (default: 'INR')
  final String currencyCode;

  const Money(this.minorUnits, {this.currencyCode = 'INR'});

  /// Creates a Money instance from integer minor units (e.g. 15050 paise = ₹150.50)
  const factory Money.fromMinor(int minorUnits, {String currencyCode}) = Money;

  /// Creates a Money instance from major units (e.g. ₹150.50), safely rounding to exact minor units
  factory Money.fromMajor(double major, {String currencyCode = 'INR'}) {
    final minor = (major * 100.0).round();
    return Money(minor, currencyCode: currencyCode);
  }

  /// Zero money constant for default values
  static const Money zero = Money(0, currencyCode: 'INR');

  /// Returns major units as double for legacy bridge and chart renderers
  double get toMajor => minorUnits / 100.0;

  /// Whether the amount is strictly positive (> 0)
  bool get isPositive => minorUnits > 0;

  /// Whether the amount is strictly negative (< 0)
  bool get isNegative => minorUnits < 0;

  /// Whether the amount is zero (== 0)
  bool get isZero => minorUnits == 0;

  /// Absolute value
  Money abs() => Money(minorUnits.abs(), currencyCode: currencyCode);

  /// Operator overloads enforcing exact integer arithmetic
  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  Money operator *(num factor) {
    return Money((minorUnits * factor).round(), currencyCode: currencyCode);
  }

  Money operator -() => Money(-minorUnits, currencyCode: currencyCode);

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _assertSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError('Cannot perform arithmetic across different currencies: $currencyCode vs ${other.currencyCode}');
    }
  }

  /// Formats amount with standard localized currency symbols
  String format({String? customSymbol}) {
    final symbol = customSymbol ?? (currencyCode == 'INR' ? '₹' : '\$');
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(toMajor);
  }

  /// Backward-compatible JSON serialization: writes both minor units and major double
  Map<String, dynamic> toJson() => {
        'minorUnits': minorUnits,
        'currencyCode': currencyCode,
        'major': toMajor,
      };

  /// Backward-compatible JSON deserialization: parses integer minorUnits or legacy double
  factory Money.fromJson(dynamic json, {String defaultCurrency = 'INR'}) {
    if (json is num) {
      return Money.fromMajor(json.toDouble(), currencyCode: defaultCurrency);
    }
    if (json is Map<String, dynamic>) {
      final currency = json['currencyCode'] as String? ?? defaultCurrency;
      if (json.containsKey('minorUnits')) {
        return Money.fromMinor(json['minorUnits'] as int, currencyCode: currency);
      }
      if (json.containsKey('major')) {
        return Money.fromMajor((json['major'] as num).toDouble(), currencyCode: currency);
      }
    }
    return Money.zero;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && minorUnits == other.minorUnits && currencyCode == other.currencyCode;

  @override
  int get hashCode => minorUnits.hashCode ^ currencyCode.hashCode;

  @override
  String toString() => '$currencyCode ${(minorUnits / 100.0).toStringAsFixed(2)}';
}
