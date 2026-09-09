import 'package:intl/intl.dart';
import '../models/settings_model.dart';

/// Centralized smart currency formatter utility respecting currency locale
/// (en_IN for INR lakhs/crores formatting, en_US for USD/international).
class CurrencyFormatter {
  const CurrencyFormatter._();

  /// Formats amount using Indian comma grouping for INR (e.g. ₹1,20,000.00)
  /// or international grouping for others (e.g. $120,000.00).
  static String format(
    double amount, {
    String currencySymbol = '₹',
    String currencyCode = 'INR',
    bool includeSymbol = true,
    int decimalDigits = 2,
  }) {
    final isIndian = currencyCode.toUpperCase() == 'INR' || currencySymbol == '₹';
    final formatter = NumberFormat.currency(
      locale: isIndian ? 'en_IN' : 'en_US',
      symbol: includeSymbol ? currencySymbol : '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount).trim();
  }

  /// Compact currency format with proper locale grouping (e.g. ₹1.2L or $120K).
  static String formatCompact(
    double amount, {
    String currencySymbol = '₹',
    String currencyCode = 'INR',
    bool includeSymbol = true,
  }) {
    final isIndian = currencyCode.toUpperCase() == 'INR' || currencySymbol == '₹';
    final formatter = NumberFormat.compactCurrency(
      locale: isIndian ? 'en_IN' : 'en_US',
      symbol: includeSymbol ? currencySymbol : '',
    );
    return formatter.format(amount).trim();
  }

  /// Convenience helper using user settings.
  static String formatWithSettings(
    double amount,
    UserSettingsModel settings, {
    bool includeSymbol = true,
    int decimalDigits = 2,
  }) {
    return format(
      amount,
      currencySymbol: settings.currencySymbol,
      currencyCode: settings.currencyCode,
      includeSymbol: includeSymbol,
      decimalDigits: decimalDigits,
    );
  }

  /// Compact convenience helper using user settings.
  static String formatCompactWithSettings(
    double amount,
    UserSettingsModel settings, {
    bool includeSymbol = true,
  }) {
    return formatCompact(
      amount,
      currencySymbol: settings.currencySymbol,
      currencyCode: settings.currencyCode,
      includeSymbol: includeSymbol,
    );
  }
}
