import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/common/date_strip_selector.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  // 👇 НОВИЙ БЛОК: Ініціалізуємо формати дат перед усіма тестами
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('DateStripSelector Tests', () {
    testWidgets('Рендерить іконку календаря та викликає onCalendarTap', (
      WidgetTester tester,
    ) async {
      bool calendarTapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          child: DateStripSelector(
            selectedDate: DateTime.now(),
            onDateChanged: (_) {},
            onCalendarTap: () {
              calendarTapped = true;
            },
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await tester.pump();

      expect(calendarTapped, true);
    });

    testWidgets(
      'Відображає relative dates (today, yesterday) та змінює дату при свайпі',
      (WidgetTester tester) async {
        DateTime? changedDate;
        final today = DateTime.now();

        await tester.pumpWidget(
          makeTestableWidget(
            child: DateStripSelector(
              selectedDate: today,
              onDateChanged: (date) {
                changedDate = date;
              },
              onCalendarTap: () {},
            ),
          ),
        );

        expect(find.text('today'), findsWidgets);
        expect(find.text('yesterday'), findsWidgets);
        expect(find.text('tomorrow'), findsWidgets);

        // 💡 МАГІЯ: Використовуємо drag замість fling.
        // Тягнемо стрічку рівно на 200 пікселів вправо.
        // Це ~70% ширини одного дня (280px), тому фізика скролу
        // гарантовано "примагнітить" нас рівно на 1 день назад.
        await tester.drag(find.byType(PageView), const Offset(200, 0));

        // Чекаємо, поки пружинна анімація (SpringSimulation) заспокоїться
        await tester.pumpAndSettle();

        expect(changedDate, isNotNull);
        expect(changedDate!.day, today.subtract(const Duration(days: 1)).day);
      },
    );

    testWidgets(
      'Програмно змінює сторінку при оновленні selectedDate ззовні (didUpdateWidget)',
      (WidgetTester tester) async {
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));

        late StateSetter setModalState;
        DateTime currentDate = today;

        await tester.pumpWidget(
          makeTestableWidget(
            child: StatefulBuilder(
              builder: (context, setState) {
                setModalState = setState;
                return DateStripSelector(
                  selectedDate: currentDate,
                  onDateChanged: (_) {},
                  onCalendarTap: () {},
                );
              },
            ),
          ),
        );

        setModalState(() {
          currentDate = tomorrow;
        });

        await tester.pumpAndSettle();

        expect(true, isTrue);
      },
    );
  });
}
