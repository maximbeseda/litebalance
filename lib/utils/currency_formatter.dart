// lib/utils/currency_formatter.dart
class CurrencyFormatter {
  /// Скорочення для мільйонів (напр. «1,5М»). Локалізується застосунком:
  /// `MyApp` оновлює це поле з ключа `million_suffix` при кожній зміні мови.
  /// Тримаємо значення тут (а не через `.tr()`), щоб форматер лишався чистим
  /// і тестувався без ініціалізації локалізації.
  static String millionSuffix = 'М';

  // Швидкий метод для розділення тисяч
  static String _addSpaces(String integerPart) {
    if (integerPart.length <= 3) return integerPart;

    final buffer = StringBuffer();
    int count = 0;

    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 3) {
        buffer.write(' ');
        count = 0;
      }
      buffer.write(integerPart[i]);
      count++;
    }

    return buffer.toString().split('').reversed.join();
  }

  static String format(int amount, {bool isHeader = false}) {
    if (amount == 0) return '0';

    // 👇 ТЕПЕР МАТЕМАТИКА ПРАВИЛЬНА (Беремо копійки з бази)
    final int absCents = amount.abs();
    final String sign = amount < 0 ? '-' : '';

    // Понад 100 мільярдів
    if (absCents >= 10000000000000) return '${sign}99 999$millionSuffix+';

    // Поріг для мільйонів (у копійках)
    final int millionThresholdCents = isHeader ? 10000000000 : 100000000;

    if (absCents >= millionThresholdCents) {
      final double millions = (absCents / 100.0) / 1000000.0;
      final int integerPart = millions.truncate();
      final int fractionalPart = ((millions - integerPart) * 10).truncate();

      final String formattedInteger = _addSpaces(integerPart.toString());
      return '$sign$formattedInteger,$fractionalPart$millionSuffix';
    }

    // ЗВИЧАЙНІ СУМИ: Беремо цілу та дробову частину математично!
    final int iPart = absCents ~/ 100; // Це цілі гривні/долари
    final int fPart = absCents % 100; // Це залишок (копійки/центи)

    final String formattedInt = _addSpaces(iPart.toString());

    // Якщо сума >= 100 000 (тобто 10 000 000 копійок), показуємо без копійок
    if (absCents >= 10000000) return '$sign$formattedInt';

    final String fString = fPart.toString().padLeft(2, '0');
    return '$sign$formattedInt,$fString';
  }

  /// Повна сума без копійок і без скорочень (напр. "1 234 567").
  /// Для місць, де важливо бачити точне число (його варто масштабувати
  /// FittedBox, щоб вміщалося на малих екранах).
  static String formatFull(int amount) {
    final int iPart = amount.abs() ~/ 100;
    final String sign = amount < 0 ? '-' : '';
    return '$sign${_addSpaces(iPart.toString())}';
  }

  static String formatBudget(int amount) {
    final String formatted = format(amount);
    if (formatted.contains(',') && !formatted.endsWith(millionSuffix)) {
      return formatted.split(',')[0];
    }
    return formatted;
  }
}
