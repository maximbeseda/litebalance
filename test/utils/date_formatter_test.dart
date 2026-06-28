import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart'; // Потрібно для ініціалізації мов

import 'package:litebalance/utils/date_formatter.dart';

void main() {
  // setUpAll виконується один раз перед запуском усіх тестів у цьому файлі
  setUpAll(() async {
    // Завантажуємо правила форматування для потрібних мов
    await initializeDateFormatting('uk', null);
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('en_US', null);
  });

  group('DateFormatter Tests', () {
    // Створюємо фіксовану дату для перевірки: 22 березня 2026 року, 21:05
    final testDate = DateTime(2026, 3, 22, 21, 5);

    test('formatFull повертає коротку дату у форматі локалі', () {
      // uk — день.місяць.рік; en_US — місяць/день/рік
      expect(DateFormatter.formatFull(testDate, 'uk'), '22.03.2026');
      expect(DateFormatter.formatFull(testDate, 'en_US'), '3/22/2026');
    });

    test('formatWithTime повертає дату з часом за локаллю', () {
      // uk — 24-годинний формат
      expect(DateFormatter.formatWithTime(testDate, 'uk'), '22.03.2026 21:05');
      // en_US — 12-годинний з AM/PM (intl ставить вузький нерозривний пробіл
      // перед PM, тож перевіряємо складові, а не точний пробіл).
      final enTime = DateFormatter.formatWithTime(testDate, 'en_US');
      expect(enTime, startsWith('3/22/2026'));
      expect(enTime, contains('9:05'));
      expect(enTime, endsWith('PM'));
    });

    test('formatDay повинен повертати тільки день', () {
      expect(DateFormatter.formatDay(testDate), '22');
    });

    test('formatMonthYear повинен повертати місяць і рік (англійською)', () {
      // В англійській березень - March
      expect(DateFormatter.formatMonthYear(testDate, 'en'), 'March 2026');
    });

    test('formatMonthYear повинен повертати місяць і рік (українською)', () {
      // Перевіряємо також, що перша літера велика
      expect(DateFormatter.formatMonthYear(testDate, 'uk'), 'Березень 2026');
    });
  });
}
