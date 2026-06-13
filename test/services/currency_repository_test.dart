import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart'; // Спеціальна бібліотека для моків HTTP
import 'dart:convert';

import 'package:litebalance/services/currency_repository.dart'; // Вкажіть ваш шлях

void main() {
  group('FawazahmedApi - API Client Tests', () {
    test(
      'fetchLatestRates парсить JSON і переводить ключі у верхній регістр',
      () async {
        // 1. Створюємо фейковий інтернет
        final mockClient = MockClient((request) async {
          // Повертаємо успішну відповідь з фейковим JSON
          return http.Response(
            jsonEncode({
              'date': '2026-04-25',
              'usd': {'eur': 0.95, 'uah': 40.1, 'jpy': 150.0},
            }),
            200,
          );
        });

        // 2. Віддаємо фейковий клієнт нашому сервісу
        final api = FawazahmedApi(client: mockClient);
        final rates = await api.fetchLatestRates('USD');

        // 3. Перевіряємо бізнес-логіку
        expect(rates, isNotNull);
        expect(rates!['UAH'], 40.1);
        expect(rates['EUR'], 0.95);

        // Перевіряємо, чи метод справді підняв регістр ключів (eur -> EUR)
        expect(rates.containsKey('EUR'), true);
        expect(rates.containsKey('eur'), false);
      },
    );

    test(
      'Fallback: якщо перший сервер падає, запит йде на другий (дзеркало)',
      () async {
        int requestCount = 0;

        final mockClient = MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            // Імітуємо падіння першого сервера
            return http.Response('Internal Server Error', 500);
          }
          // Другий сервер відповідає успішно
          return http.Response(
            jsonEncode({
              'usd': {'uah': 39.5},
            }),
            200,
          );
        });

        final api = FawazahmedApi(client: mockClient);
        final rates = await api.fetchLatestRates('USD');

        expect(requestCount, 2); // Спрацював Fallback! Зроблено 2 запити.
        expect(rates!['UAH'], 39.5);
      },
    );

    test('fetchHistoricalRates правильно формує YYYY-MM-DD для URL', () async {
      String interceptedUrl = '';

      final mockClient = MockClient((request) async {
        interceptedUrl = request.url.toString();
        return http.Response(
          jsonEncode({
            'eur': {'usd': 1.1},
          }),
          200,
        );
      });

      final api = FawazahmedApi(client: mockClient);
      // Передаємо дату: 5 березня 2026
      await api.fetchHistoricalRates('EUR', DateTime(2026, 3, 5));

      // Перевіряємо, чи в URL підставилися нулі (03, 05)
      expect(interceptedUrl.contains('2026-03-05'), true);
    });

    test('Повертає null при "битому" JSON або помилці парсингу', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Ой, це HTML, а не JSON <h1>Помилка</h1>', 200);
      });

      final api = FawazahmedApi(client: mockClient);
      final rates = await api.fetchLatestRates('USD');

      // Має спрацювати блок catch і повернути null без "крашу" додатку
      expect(rates, isNull);
    });
  });
}
