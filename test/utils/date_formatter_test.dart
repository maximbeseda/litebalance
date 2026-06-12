import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart'; // Потрібно для ініціалізації мов

import 'package:litebalance/utils/date_formatter.dart';

void main() {
  // setUpAll виконується один раз перед запуском усіх тестів у цьому файлі
  setUpAll(() async {
    // Завантажуємо правила форматування для української та англійської мов
    await initializeDateFormatting('uk', null);
    await initializeDateFormatting('en', null);
  });

  group('DateFormatter Tests', () {
    // Створюємо фіксовану дату для перевірки: 22 березня 2026 року, 21:05
    final testDate = DateTime(2026, 3, 22, 21, 5);

    test('formatFull повинен повертати дату у форматі dd.MM.yyyy', () {
      expect(DateFormatter.formatFull(testDate), '22.03.2026');
    });

    test('formatWithTime повинен повертати дату з часом', () {
      expect(DateFormatter.formatWithTime(testDate), '22.03.2026 21:05');
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
