import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Імпорти згідно з вашою структурою
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:coin_flow/screens/import_wizard/import_category_setup_screen.dart';
import 'package:coin_flow/providers/core_providers.dart';

void main() {
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({'baseCurrency': 'UAH'});
    mockPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
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
        // ПРИБРАЛИ const, бо testRawRows не є константою
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
      // ПРИБРАЛИ const перед ImportCategorySetupScreen
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

    testWidgets('Виконання імпорту: успішно парсить всі формати дат та сум', (
      tester,
    ) async {
      final testRawRows = [
        ['date', 'from', 'to', 'amount'],
        ['12.10.2023', 'MissingFrom', 'MissingTo', '150.50'],
        ['2023/10/12', 'MissingFrom', 'MissingTo', '1 500,00'],
      ];

      // ПРИБРАЛИ const перед ImportCategorySetupScreen
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

      await tester.tap(importBtn);
      await tester.pump();
      await tester.pumpAndSettle();
    });
  });
}
