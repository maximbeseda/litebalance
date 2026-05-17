import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ЗАМІНІТЬ імпорти на ваші реальні шляхи, використовуючи coin_flow
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:coin_flow/screens/import_wizard/import_column_mapping_screen.dart';
import 'package:coin_flow/screens/import_wizard/import_category_setup_screen.dart';

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

  // Допоміжна функція: обгортаємо віджет у ProviderScope та MaterialApp
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: const [mockColors]),
        home: child,
      ),
    );
  }

  group('ImportColumnMappingScreen Tests', () {
    testWidgets('Віджет рендериться і створює випадаючі списки (Dropdowns)', (
      tester,
    ) async {
      // Дані, де заголовки НЕ розпізнаються автоматично
      final testRawRows = [
        ['Col1', 'Col2', 'Col3'],
        ['12.10', '100', 'Cat'],
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          ImportColumnMappingScreen(rawRows: testRawRows, headerRowIndex: 0),
        ),
      );

      // ВИПРАВЛЕННЯ: Додаємо skipOffstage: false, щоб знайти списки, які не влізли на екран
      expect(
        find.byType(DropdownButton<int?>, skipOffstage: false),
        findsNWidgets(8),
      );

      // Перевіряємо наявність кнопки "Далі"
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets(
      'Показує помилку (SnackBar), якщо не обрано обов\'язкові колонки',
      (tester) async {
        // Дані без розпізнаваних заголовків -> Date та Amount будуть null
        final testRawRows = [
          ['Unrecognized1', 'Unrecognized2'],
          ['Data1', 'Data2'],
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            ImportColumnMappingScreen(rawRows: testRawRows, headerRowIndex: 0),
          ),
        );

        // Тапаємо кнопку "Далі"
        await tester.tap(find.byType(ElevatedButton));

        // Відмальовуємо появу SnackBar
        await tester.pump();

        // Перевіряємо, чи з'явився SnackBar із помилкою
        expect(find.byType(SnackBar), findsOneWidget);

        // Перевіряємо, що переходу НЕ відбулося
        expect(find.byType(ImportCategorySetupScreen), findsNothing);
      },
    );

    testWidgets('Успішний перехід на Крок 3 при наявності потрібних колонок', (
      tester,
    ) async {
      // Дані з розпізнаваними заголовками: Date та Amount (ImportRecognizer має їх вгадати)
      final testRawRows = [
        ['date', 'from', 'amount'], // Рядок заголовків
        ['12.10.2023', 'Wallet', '150'], // Дані
        ['13.10.2023', 'Salary', '2000'], // Дані
        ['', '', ''], // Порожній рядок (симулює кінець файлу)
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          ImportColumnMappingScreen(rawRows: testRawRows, headerRowIndex: 0),
        ),
      );

      // Оскільки ImportRecognizer має автоматично розпізнати 'date' та 'amount',
      // форма вже є валідною. Тапаємо "Далі".
      await tester.tap(find.byType(ElevatedButton));

      // Чекаємо завершення анімації переходу (Navigator.push)
      await tester.pumpAndSettle();

      // Перевіряємо, чи з'явився на екрані віджет Кроку 3
      expect(find.byType(ImportCategorySetupScreen), findsOneWidget);
    });
  });
}
