import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Розкоментуйте цей рядок, якщо використовуєте ініціалізацію локалізації в тестах
// import 'package:easy_localization/easy_localization.dart';

// ЗАМІНІТЬ імпорти на ваші реальні шляхи
import 'package:litebalance/theme/app_colors_extension.dart';
import 'package:litebalance/screens/import_wizard/import_header_selection_screen.dart';
import 'package:litebalance/screens/import_wizard/import_column_mapping_screen.dart';

void main() {
  // 1. СТВОРЮЄМО ФЕЙКОВУ ТЕМУ ДЛЯ ТЕСТІВ
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

  // 2. ФЕЙКОВІ ДАНІ ДЛЯ ІМІТАЦІЇ CSV ФАЙЛУ
  final testRawRows = [
    ['Дата', 'Сума', 'Категорія'], // Рядок 0: Валідний заголовок
    ['12.10.2023', '150.50', 'Сільпо'], // Рядок 1: Невалідний (є дата)
    ['', '', ''], // Рядок 2: Невалідний (порожній)
  ];

  // Допоміжна функція для обгортання віджета в MaterialApp з темою
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      // Забезпечуємо віджет нашими кольорами
      theme: ThemeData(extensions: const [mockColors]),
      home: child,
    );
  }

  // Опціонально: Налаштування EasyLocalization для тестів, якщо необхідно
  // setUpAll(() async {
  //   await EasyLocalization.ensureInitialized();
  // });

  group('ImportHeaderSelectionScreen Tests', () {
    testWidgets('Віджет рендериться коректно та показує дані таблиці', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(ImportHeaderSelectionScreen(rawRows: testRawRows)),
      );

      // Перевіряємо, чи відображаються дані з нашого масиву на екрані
      expect(find.text('Дата'), findsOneWidget);
      expect(find.text('Сума'), findsOneWidget);
      expect(find.text('12.10.2023'), findsOneWidget);
      expect(find.text('Сільпо'), findsOneWidget);

      // Перевіряємо, чи є кнопка "Далі" (ElevatedButton)
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Кнопка "Далі" не працює, якщо не обрано жодного рядка', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(ImportHeaderSelectionScreen(rawRows: testRawRows)),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      // Якщо onPressed дорівнює null, кнопка вимкнена
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'Показує помилку (SnackBar), якщо обрано рядок із даними (датами)',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            ImportHeaderSelectionScreen(rawRows: testRawRows),
          ),
        );

        // 1. Тапаємо на рядок з даними (Рядок 1)
        await tester.tap(find.text('12.10.2023'));
        await tester.pumpAndSettle();

        // 2. Кнопка тепер має бути активною. Тапаємо на неї
        await tester.tap(find.byType(ElevatedButton));

        // 3. Робимо pump (без settle), щоб запустити анімацію появи SnackBar
        await tester.pump();

        // 4. Перевіряємо, чи з'явився SnackBar
        expect(find.byType(SnackBar), findsOneWidget);

        // Перевіряємо, чи не відбулося переходу на наступний екран
        expect(find.byType(ImportColumnMappingScreen), findsNothing);
      },
    );

    testWidgets('Успішний перехід на Крок 2 при виборі валідного заголовка', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(ImportHeaderSelectionScreen(rawRows: testRawRows)),
      );

      // 1. Тапаємо на валідний заголовок (Рядок 0)
      await tester.tap(find.text('Дата'));
      await tester.pumpAndSettle();

      // 2. Тапаємо кнопку "Далі"
      await tester.tap(find.byType(ElevatedButton));

      // 3. Чекаємо завершення анімації переходу (Navigator.push)
      await tester.pumpAndSettle();

      // 4. Перевіряємо, чи з'явився на екрані віджет Кроку 2
      expect(find.byType(ImportColumnMappingScreen), findsOneWidget);
    });
  });
}
