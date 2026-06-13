import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/dialogs/custom_date_range_picker.dart';
import 'package:litebalance/theme/app_colors_extension.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  // Імітація кольорів для віджета
  const testColors = AppColorsExtension(
    bgGradientStart: Colors.black,
    bgGradientEnd: Colors.black,
    cardBg: Colors.white,
    textMain: Colors.black,
    textSecondary: Colors.grey,
    income: Colors.green,
    expense: Colors.red,
    iconBg: Colors.blue,
    accent: Colors.orange,
  );

  // Допоміжна функція для відкриття BottomSheet
  Future<void> pumpAndOpenPicker(
    WidgetTester tester, {
    DateTimeRange? initialRange,
    required void Function(dynamic) onResult,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      makeTestableWidget(
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // Щоб шторка розгорнулася повністю
                  builder: (_) => CustomDateRangePicker(
                    initialRange: initialRange,
                    colors: testColors,
                  ),
                );
                onResult(result);
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();
  }

  group('CustomDateRangePicker Tests', () {
    testWidgets('1. Кнопка Apply неактивна, якщо не вибрано жодної дати', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenPicker(tester, initialRange: null, onResult: (_) {});

      // Перевіряємо заголовки
      expect(find.text('filter_period'), findsOneWidget);
      expect(find.text('filter_select_period'), findsOneWidget);

      // Знаходимо кнопку Apply
      final applyBtnFinder = find.widgetWithText(ElevatedButton, 'apply');
      expect(applyBtnFinder, findsOneWidget);

      // Перевіряємо, чи кнопка Disabled (onPressed == null)
      final ElevatedButton btn = tester.widget(applyBtnFinder);
      expect(btn.onPressed, isNull);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Повертає ResetRangeSignal при натисканні на Reset', (
      WidgetTester tester,
    ) async {
      dynamic returnedResult;
      await pumpAndOpenPicker(
        tester,
        initialRange: null,
        onResult: (res) => returnedResult = res,
      );

      // Натискаємо на текст скидання
      await tester.tap(find.text('reset'));
      await tester.pumpAndSettle(); // Чекаємо закриття

      // Результат має бути об'єктом ResetRangeSignal
      expect(returnedResult, isA<ResetRangeSignal>());

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      '3. Кнопка Apply активна і повертає діапазон, якщо передано initialRange',
      (WidgetTester tester) async {
        final initRange = DateTimeRange(
          start: DateTime(2023, 10, 1),
          end: DateTime(2023, 10, 5),
        );

        dynamic returnedResult;
        await pumpAndOpenPicker(
          tester,
          initialRange: initRange,
          onResult: (res) => returnedResult = res,
        );

        // Кнопка має бути активною
        final applyBtnFinder = find.widgetWithText(ElevatedButton, 'apply');
        final ElevatedButton btn = tester.widget(applyBtnFinder);
        expect(btn.onPressed, isNotNull);

        // Натискаємо Apply
        await tester.tap(applyBtnFinder);
        await tester.pumpAndSettle();

        // Має повернути той самий DateTimeRange
        expect(returnedResult, isA<DateTimeRange>());
        final resultRange = returnedResult as DateTimeRange;
        expect(resultRange.start, equals(initRange.start));
        expect(resultRange.end, equals(initRange.end));

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets('4. Дозволяє обрати дату і активує кнопку Apply', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenPicker(tester, initialRange: null, onResult: (_) {});

      // Список генерується задом наперед. Майбутні дати заблоковані.
      // Знайдемо день '15' в списку відрендерених днів (гарантовано буде хоч один в минулому)
      // Беремо .last, оскільки це зворотний список, і last точно буде десь в минулих роках
      final pastDayFinder = find.text('15').last;

      await tester.tap(pastDayFinder);
      await tester.pumpAndSettle();

      // Після вибору однієї дати кнопка Apply має стати активною
      final applyBtnFinder = find.widgetWithText(ElevatedButton, 'apply');
      final ElevatedButton btn = tester.widget(applyBtnFinder);
      expect(btn.onPressed, isNotNull);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
