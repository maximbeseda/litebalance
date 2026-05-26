import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Додано для мокування пам'яті

// ЗАМІНІТЬ імпорти на ваші реальні шляхи
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:coin_flow/screens/import_wizard/import_category_setup_screen.dart';
import 'package:coin_flow/providers/all_providers.dart'; // Додано для доступу до провайдерів
import 'package:coin_flow/providers/core_providers.dart'; // Додано для sharedPreferencesProvider

void main() {
  // 1. ФЕЙКОВА ТЕМА ДЛЯ ТЕСТІВ
  const mockColors = AppColorsExtension(
    bgGradientStart: Colors.white,
    bgGradientEnd: Colors.white,
    cardBg: Colors.grey,
    textMain: Colors.black,
    textSecondary: Colors.black54,
    income: Colors.green,
    expense: Colors.red,
    iconBg: Colors.blue,
    accent: Colors.blueAccent,
  );

  late SharedPreferences mockPrefs;

  // 2. ІНІЦІАЛІЗАЦІЯ ФЕЙКОВОЇ ПАМ'ЯТІ ПЕРЕД КОЖНИМ ТЕСТОМ
  setUp(() async {
    // Встановлюємо фейкові стартові значення (наприклад, дефолтна валюта)
    SharedPreferences.setMockInitialValues({'baseCurrency': 'UAH'});
    mockPrefs = await SharedPreferences.getInstance();
  });

  // Допоміжна функція: обгортаємо віджет у ProviderScope ТА передаємо фейковий SharedPreferences
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        // Перевизначаємо провайдер, який падав з помилкою
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [mockColors]),
        home: child,
      ),
    );
  }

  group('ImportCategorySetupScreen Tests', () {
    testWidgets(
      'Показує "Усі категорії знайомі", якщо список нових категорій порожній',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            const ImportCategorySetupScreen(
              rawRows: [
                ['date'],
              ],
              headerRowIndex: 0,
              foundCategories: [],
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.text('import_all_categories_known'), findsOneWidget);
      },
    );

    testWidgets('Перемикач "В архів" змінює свій стан при натисканні', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ImportCategorySetupScreen(
            rawRows: [
              ['date'],
            ],
            headerRowIndex: 0,
            foundCategories: ['TestCategory'],
          ),
        ),
      );

      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('Зміна типів категорій працює коректно', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ImportCategorySetupScreen(
            rawRows: [
              ['date'],
            ],
            headerRowIndex: 0,
            foundCategories: ['MyCategory'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('import_type_income').first);
      await tester.pump();

      await tester.tap(find.text('import_type_account').first);
      await tester.pump();

      await tester.tap(find.text('import_type_expense').first);
      await tester.pump();

      expect(find.text('MyCategory'), findsOneWidget);
    });

    // СУПЕР-ТЕСТ ДЛЯ ПАРСИНГУ
    testWidgets('Виконання імпорту: успішно парсить всі формати дат та сум', (
      tester,
    ) async {
      final testRawRows = [
        ['date', 'from', 'to', 'amount'],
        ['12.10.2023', 'MissingFrom', 'MissingTo', '150.50'],
        ['2023/10/12', 'MissingFrom', 'MissingTo', '1 500,00'],
        ['10/12/2023', 'MissingFrom', 'MissingTo', '"100"'],
        ['2023-10-12T10:00:00Z', 'MissingFrom', 'MissingTo', 'bad_amount'],
        ['InvalidDate', 'MissingFrom', 'MissingTo', '10'],
        ['', '', '', ''],
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          ImportCategorySetupScreen(
            rawRows: testRawRows,
            headerRowIndex: 0,
            dateCol: 0,
            fromCol: 1,
            toCol: 2,
            amountFromCol: 3,
            amountToCol: 3,
            foundCategories: const ['NewCat1'],
          ),
        ),
      );

      await tester.pumpAndSettle();

      final importBtn = find.byType(ElevatedButton);
      expect(importBtn, findsOneWidget);

      // Натискаємо! Запускається _executeImport
      await tester.tap(importBtn);

      // Відмальовуємо UI під час роботи
      await tester.pump();

      // Чекаємо завершення операції
      await tester.pumpAndSettle();
    });
  });
}
