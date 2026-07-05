import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/models/app_currency.dart';
import 'package:litebalance/utils/app_constants.dart';

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

  group('Цілісність назв валют у перекладах', () {
    final translationFiles = Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('к-сть файлів перекладу збігається зі списком мов застосунку', () {
      expect(translationFiles.length, AppConstants.languages.length);
    });

    for (final file in translationFiles) {
      final locale = file.uri.pathSegments.last.replaceAll('.json', '');

      test('[$locale] має назву для кожної підтримуваної валюти', () {
        final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
        final names = (data['currency_names'] as Map<String, dynamic>?) ?? {};

        final missing = <String>[];
        for (final c in AppCurrency.supportedCurrencies) {
          final name = names[c.code];
          if (name == null || (name as String).trim().isEmpty) {
            missing.add(c.code);
          }
        }

        expect(
          missing,
          isEmpty,
          reason: 'У [$locale] бракує назв для: ${missing.join(', ')}',
        );
      });
    }
  });
}
