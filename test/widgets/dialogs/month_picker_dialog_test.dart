import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/dialogs/month_picker_dialog.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    // Ініціалізуємо формати для DateFormat
    await initializeDateFormatting('en', null);
  });

  // Допоміжна функція для відкриття діалогу
  Future<void> pumpAndOpenDialog(
    WidgetTester tester,
    DateTime initialDate,
    void Function(DateTime?) onResult,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      makeTestableWidget(
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showDialog<DateTime>(
                  context: context,
                  builder: (_) => MonthPickerDialog(initialDate: initialDate),
                );
                onResult(result);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Відкриваємо діалог
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('MonthPickerDialog Tests', () {
    final testInitialDate = DateTime(2025, 5, 15); // Травень 2025

    testWidgets('1. Відображає поточний рік та 12 місяців', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenDialog(tester, testInitialDate, (_) {});

      // Перевіряємо, чи відображається правильний рік
      expect(find.text('2025'), findsOneWidget);

      // Перевіряємо, чи намалювалась сітка (GridView)
      expect(find.byType(GridView), findsOneWidget);

      // Перевіряємо наявність стрілок "Вліво" та "Вправо"
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Перевіряємо наявність кнопки "Поточний місяць"
      expect(find.text('current_month'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Стрілки перемикають роки', (WidgetTester tester) async {
      await pumpAndOpenDialog(tester, testInitialDate, (_) {});

      // Спочатку 2025
      expect(find.text('2025'), findsOneWidget);

      // Натискаємо стрілку Вліво
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Має стати 2024
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2025'), findsNothing);

      // Натискаємо стрілку Вправо двічі
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Має стати 2026
      expect(find.text('2026'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Вибір місяця повертає правильну дату', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate;
      await pumpAndOpenDialog(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Перемикаємо рік на 2026
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Натискаємо на Серпень (August - Aug).
      // Знаходимо текст 'Aug' у сітці
      await tester.tap(find.text('Aug'));
      await tester.pumpAndSettle();

      // Перевіряємо результат: має повернутися 1 Серпня 2026
      expect(returnedDate, isNotNull);
      expect(returnedDate!.year, 2026);
      expect(returnedDate!.month, 8); // Серпень — 8-й місяць
      expect(returnedDate!.day, 1); // Завжди повертає перше число

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('4. Кнопка "Поточний місяць" повертає правильну дату', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate;
      await pumpAndOpenDialog(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Натискаємо на 'current_month'
      await tester.tap(find.text('current_month'));
      await tester.pumpAndSettle();

      final now = DateTime.now();

      // Має повернутися перший день поточного реального місяця та року
      expect(returnedDate, isNotNull);
      expect(returnedDate!.year, now.year);
      expect(returnedDate!.month, now.month);
      expect(returnedDate!.day, 1);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
