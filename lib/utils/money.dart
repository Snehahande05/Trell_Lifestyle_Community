// utils/money.dart
// Helper for handling monetary amounts in minor units (e.g., paise).
// All amounts are stored as integers to avoid floating point drift.
// Rounding rule: round half up when dividing.

class Money {
  final int minorUnits; // e.g., paise
  const Money(this.minorUnits);

  // Factory from major units (rupees) with optional decimal part.
  factory Money.fromMajor(double amount) {
    // Multiply by 100 and round half up.
    int minor = (amount * 100).round();
    return Money(minor);
  }

  // Add two Money values.
  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);
  Money operator *(int factor) => Money(minorUnits * factor);
  Money operator ~/(int divisor) {
    // Integer division with round half up.
    double result = minorUnits / divisor;
    return Money(result.round());
  }

  // Convert to formatted string with currency symbol.
  String format({String symbol = '₹'}) {
    int rupees = minorUnits ~/ 100;
    int paise = minorUnits % 100;
    String paiseStr = paise.toString().padLeft(2, '0');
    return '$symbol$rupees.$paiseStr';
  }

  @override
  String toString() => format();
}
