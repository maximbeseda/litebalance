import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/models/app_currency.dart';

void main() {
  group('AppCurrency Model Tests', () {
    test('fromCode повинен повертати правильну валюту для існуючого коду', () {
      final usd = AppCurrency.fromCode('USD');
      expect(usd.code, 'USD');
      expect(usd.symbol, '\$');
    });

    test(
      'fromCode повинен повертати дефолтну валюту (UAH) для неіснуючого коду',
      () {
        final unknown = AppCurrency.fromCode('XYZ');
        expect(unknown.code, 'UAH');
      },
    );

    test('toJson та fromJson повинні коректно працювати в парі', () {
      // Тут було правильно: const
      const original = AppCurrency(code: 'EUR', symbol: '€');
      final json = original.toJson();
      final fromJson = AppCurrency.fromJson(json);

      expect(fromJson.code, 'EUR');
      expect(fromJson.symbol, '€');
      expect(fromJson, original);
    });

    test('Об\'єкти з однаковим кодом повинні бути рівними', () {
      final c1 = AppCurrency.fromCode('USD');

      // 👇 ВИПРАВЛЕНО: замінили final на const
      const c2 = AppCurrency(code: 'USD', symbol: '\$');

      expect(c1 == c2, true);
      expect(c1.hashCode == c2.hashCode, true);
    });
  });
}
