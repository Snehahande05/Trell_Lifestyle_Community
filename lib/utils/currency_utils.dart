class CurrencyUtils {
  /// Formats integer paise to INR display format.
  /// Example: 80000 paise -> "₹800.00"
  static String formatPaise(int paise) {
    double rupees = paise / 100.0;
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Formats integer paise as whole rupees if no fractional part, or rounded integer rupees
  static String formatPaiseCompact(int paise) {
    double rupees = paise / 100.0;
    if (rupees % 1 == 0) {
      return '₹${rupees.toInt()}';
    }
    return '₹${rupees.toStringAsFixed(2)}';
  }
}
