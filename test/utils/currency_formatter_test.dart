import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('Повинен повертати "0" для суми 0', () {
      expect(CurrencyFormatter.format(0), '0');
    });

    test('Повинен правильно ділити копійки на ціле число та дріб', () {
      // 15050 копійок = 150,50
      expect(CurrencyFormatter.format(15050), '150,50');
    });

    test('Повинен додавати пробіли для розділення тисяч', () {
      // 150000 копійок = 1 500,00
      expect(CurrencyFormatter.format(150000), '1 500,00');
    });

    test('Повинен додавати знак мінус для відємних сум', () {
      // -5000 копійок = -50,00
      expect(CurrencyFormatter.format(-5000), '-50,00');
    });

    test(
      'Повинен форматувати великі суми з літерою М для заголовка (isHeader)',
      () {
        // 10 000 000 000 копійок з увімкненим isHeader
        expect(CurrencyFormatter.format(10000000000, isHeader: true), '100,0М');
      },
    );

    test('Повинен ставити заглушку для надзвичайно великих сум', () {
      // Суми понад 100 мільярдів
      expect(CurrencyFormatter.format(10000000000000), '99 999М+');
    });

    test('Повинен показувати копійки для сум ДО 100 000', () {
      // 99 999,99 = 9999999 копійок
      expect(CurrencyFormatter.format(9999999), '99 999,99');
    });

    test('Повинен приховувати копійки для сум ВІД 100 000', () {
      // 100 000,00 = 10000000 копійок
      expect(CurrencyFormatter.format(10000000), '100 000');
    });

    test(
      'Повинен скорочувати до мільйонів (М) для сум ВІД 1 000 000 (звичайний режим)',
      () {
        // 1 500 000,00 = 150000000 копійок -> очікуємо '1,5М'
        expect(CurrencyFormatter.format(150000000), '1,5М');
      },
    );

    test('formatBudget повинен відкидати копійки для звичайних сум', () {
      // 1 500,50 копійок = 150050. formatBudget має повернути '1 500'
      expect(CurrencyFormatter.formatBudget(150050), '1 500');
    });
  });

  group('CurrencyFormatter — валюти без копійок', () {
    test('Для 0-знакової валюти (JPY) не показує дробову частину', () {
      // ¥1500 зберігається як 150000 (×100). Очікуємо ціле без коми.
      expect(CurrencyFormatter.format(150000, currencyCode: 'JPY'), '1 500');
    });

    test('Залишок копійок відкидається для 0-знакової валюти', () {
      expect(CurrencyFormatter.format(150050, currencyCode: 'JPY'), '1 500');
    });

    test('HUF трактується як без копійок', () {
      expect(CurrencyFormatter.format(150000, currencyCode: 'HUF'), '1 500');
    });

    test('Звичайна валюта (USD) показує 2 знаки', () {
      expect(CurrencyFormatter.format(150000, currencyCode: 'USD'), '1 500,00');
    });

    test('Від’ємна 0-знакова сума', () {
      expect(CurrencyFormatter.format(-150000, currencyCode: 'JPY'), '-1 500');
    });
  });
}
