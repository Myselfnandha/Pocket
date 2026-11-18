import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/money.dart';

void main() {
  group('Integer Minor Units (Paise) Financial Architecture Tests', () {
    test('Exact integer minor units creation and major unit conversions', () {
      final m1 = Money.fromMajor(150.50);
      expect(m1.minorUnits, 15050);
      expect(m1.toMajor, 150.50);
      expect(m1.currencyCode, 'INR');

      final m2 = Money.fromMinor(9999);
      expect(m2.minorUnits, 9999);
      expect(m2.toMajor, 99.99);
    });

    test('Eliminates IEEE-754 floating point drift in repetitive additions', () {
      // In floating-point: 0.10 * 3 = 0.30000000000000004
      // In minor units: 10 + 10 + 10 = 30 paise
      var sum = Money.zero;
      final step = Money.fromMajor(0.10);
      for (int i = 0; i < 3; i++) {
        sum = sum + step;
      }
      expect(sum.minorUnits, 30);
      expect(sum.toMajor, 0.30);
      expect(sum.format(), '₹0.30');
    });

    test('Exact integer arithmetic: addition, subtraction, multiplication, and comparison', () {
      final a = Money.fromMajor(100.25);
      final b = Money.fromMajor(50.75);

      final sum = a + b;
      expect(sum.minorUnits, 15100);
      expect(sum.toMajor, 151.00);

      final diff = a - b;
      expect(diff.minorUnits, 4950);
      expect(diff.toMajor, 49.50);

      final product = a * 2;
      expect(product.minorUnits, 20050);
      expect(product.toMajor, 200.50);

      expect(a > b, isTrue);
      expect(b < a, isTrue);
      expect(a == Money.fromMajor(100.25), isTrue);
    });

    test('Currency safety: cross-currency arithmetic throws ArgumentError', () {
      final inr = Money.fromMajor(100.0, currencyCode: 'INR');
      final usd = Money.fromMajor(100.0, currencyCode: 'USD');

      expect(() => inr + usd, throwsArgumentError);
      expect(() => inr - usd, throwsArgumentError);
      expect(() => inr.compareTo(usd), throwsArgumentError);
    });

    test('Negative balance and zero balance properties', () {
      final negative = Money.fromMajor(-450.0);
      expect(negative.isNegative, isTrue);
      expect(negative.isPositive, isFalse);
      expect(negative.abs().minorUnits, 45000);

      expect(Money.zero.isZero, isTrue);
    });

    test('Backward-compatible JSON serialization and deserialization', () {
      final original = Money.fromMajor(1234.56, currencyCode: 'INR');
      final json = original.toJson();

      expect(json['minorUnits'], 123456);
      expect(json['currencyCode'], 'INR');
      expect(json['major'], 1234.56);

      // Deserialization from map
      final restoredFromMap = Money.fromJson(json);
      expect(restoredFromMap, equals(original));

      // Deserialization from legacy raw double float
      final restoredFromDouble = Money.fromJson(1234.56);
      expect(restoredFromDouble, equals(original));

      // Deserialization from legacy raw int
      final restoredFromInt = Money.fromJson(500);
      expect(restoredFromInt.minorUnits, 50000);
    });
  });
}

