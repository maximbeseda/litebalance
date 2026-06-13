import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:litebalance/widgets/dialogs/custom_calendar_dialog.dart'; // Перевірте шлях!
import '../../helpers/test_wrapper.dart';

void main() {
  // Ініціалізуємо формати дат для пакету intl перед запуском тестів
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  // Функція-помічник для відкриття діалогу в тестовому середовищі
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
                  builder: (_) =>
                      CustomCalendarDialog(initialDate: initialDate),
                );
                onResult(result);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Натискаємо кнопку для відкриття діалогу
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('CustomCalendarDialog Tests', () {
    final testInitialDate = DateTime(
      2025,
      5,
      15,
    ); // Фіксована дата для стабільності

    testWidgets('1. Відкривається у режимі Date та відображає TableCalendar', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenDialog(tester, testInitialDate, (_) {});

      // Перевіряємо заголовок (буде ключ перекладу, бо ми в makeTestableWidget)
      expect(find.text('select_date'), findsOneWidget);

      // Перевіряємо, чи відображається календар по ключу та по типу
      expect(find.byKey(const ValueKey('calendar')), findsOneWidget);
      expect(find.byType(TableCalendar), findsOneWidget);

      // Перевіряємо, що сіток місяців та років немає на екрані
      expect(find.byKey(const ValueKey('months')), findsNothing);
      expect(find.byKey(const ValueKey('years')), findsNothing);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Перемикається між режимами (Date -> Month -> Year)', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenDialog(tester, testInitialDate, (_) {});

      // ЗНАХОДИМО І НАТИСКАЄМО НА МІСЯЦЬ (наприклад, 'May')
      // Оскільки _getMonthName бере місяць з дати, це буде текст поточного місяця.
      // Ми натискаємо на іконку стрілочки вниз поруч із місяцем
      final monthDropdownIcon = find.byIcon(Icons.keyboard_arrow_down).first;
      await tester.tap(monthDropdownIcon);
      await tester.pumpAndSettle(); // Чекаємо на анімацію AnimatedSize

      // Перевіряємо, що з'явилася сітка місяців, а календар зник
      expect(find.byKey(const ValueKey('months')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar')), findsNothing);

      // ЗНАХОДИМО І НАТИСКАЄМО НА РІК (2025)
      final yearDropdownIcon = find.byIcon(Icons.keyboard_arrow_down).last;
      await tester.tap(yearDropdownIcon);
      await tester.pumpAndSettle();

      // Перевіряємо, що з'явилася сітка років
      expect(find.byKey(const ValueKey('years')), findsOneWidget);
      expect(find.byKey(const ValueKey('months')), findsNothing);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Вибирає нову дату та повертає її при натисканні ОК', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate;
      await pumpAndOpenDialog(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Вибираємо 20-те число поточного місяця (травня).
      // TableCalendar малює числа текстом, тому шукаємо текст '20'.
      // Використовуємо descendant, щоб не зачепити випадковий текст деінде.
      final day20 = find
          .descendant(of: find.byType(TableCalendar), matching: find.text('20'))
          .first;

      await tester.tap(day20);
      await tester.pumpAndSettle();

      // Натискаємо кнопку 'ok'
      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle(); // Чекаємо закриття діалогу

      // Перевіряємо результат
      expect(returnedDate, isNotNull);
      expect(returnedDate!.year, 2025);
      expect(returnedDate!.month, 5);
      expect(returnedDate!.day, 20);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('4. Повертає null при натисканні Cancel', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate =
          DateTime.now(); // Даємо початкове значення, щоб перевірити, чи стане воно null

      await pumpAndOpenDialog(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Натискаємо 'cancel'
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle(); // Чекаємо закриття діалогу

      // При скасуванні showDialog повертає null
      expect(returnedDate, isNull);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
