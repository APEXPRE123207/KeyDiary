import 'package:intl/intl.dart';

/// Formatter for currencies with Rupee (INR) and custom symbol support
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats an amount string or num to INR standard (e.g. ₹5,00,000)
  static String formatInr(dynamic amount) {
    if (amount == null) return '₹0';
    num? value;
    if (amount is num) {
      value = amount;
    } else if (amount is String) {
      final sanitized = amount.replaceAll(RegExp(r'[^\d.]'), '');
      value = num.tryParse(sanitized);
    }
    if (value == null) return '₹0';
    return _inrFormat.format(value);
  }

  /// Strips formatting and extracts raw numeric string
  static String sanitize(String input) {
    return input.replaceAll(RegExp(r'[^\d.]'), '');
  }
}
