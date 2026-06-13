import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/dialogs/premium_date_picker.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  // Допоміжна функція для відкриття шторки через ваш статичний метод
  Future<void> pumpAndOpenPicker(
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
                final result = await PremiumDatePicker.show(
                  context: context,
                  initialDate: initialDate,
                );
                onResult(result);
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );

    // Відкриваємо Picker
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();
  }

  group('PremiumDatePicker Tests', () {
    final testInitialDate = DateTime(2025, 10, 15);

    testWidgets('1. Відображає всі елементи (кнопки, текст, 3 пікери)', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenPicker(tester, testInitialDate, (_) {});

      // Перевіряємо тексти заголовків (через ключі трансляції)
      expect(find.text('choose_date'), findsOneWidget);
      expect(find.text('date'), findsOneWidget);
      expect(find.text('update_date'), findsOneWidget);

      // Має бути рівно 3 CupertinoPicker (Рік, Місяць, День)
      expect(find.byType(CupertinoPicker), findsNWidgets(3));

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Відображає відформатовану передану дату', (
      WidgetTester tester,
    ) async {
      await pumpAndOpenPicker(tester, testInitialDate, (_) {});

      // Шукаємо '2025' у списку (і в пікері, і, можливо, у відформатованому рядку)
      expect(find.textContaining('2025'), findsWidgets);

      // День 15 має бути присутнім
      expect(find.textContaining('15'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Натискання "Оновити дату" повертає значення', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate;
      await pumpAndOpenPicker(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Натискаємо на кнопку "Оновити" (update_date)
      await tester.tap(find.text('update_date'));
      await tester.pumpAndSettle();

      // Оскільки ми не крутили барабан, має повернутися та ж сама початкова дата
      expect(returnedDate, isNotNull);
      expect(returnedDate!.year, 2025);
      expect(returnedDate!.month, 10);
      expect(returnedDate!.day, 15);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('4. Можна скролити CupertinoPicker і змінювати дату', (
      WidgetTester tester,
    ) async {
      DateTime? returnedDate;
      await pumpAndOpenPicker(tester, testInitialDate, (res) {
        returnedDate = res;
      });

      // Знаходимо всі пікери. Індекси: 0 - Рік, 1 - Місяць, 2 - День
      final pickers = find.byType(CupertinoPicker);
      expect(pickers, findsNWidgets(3));

      // Тягнемо пікер "День" (індекс 2) трохи вниз, щоб вибрати попередній день (14 замість 15)
      // В тестах Flutter drag працює дуже точно
      await tester.drag(pickers.at(2), const Offset(0, 40));
      await tester.pumpAndSettle();

      // Натискаємо "Оновити"
      await tester.tap(find.text('update_date'));
      await tester.pumpAndSettle();

      // Має повернутися змінена дата (14 число)
      expect(returnedDate, isNotNull);
      expect(returnedDate!.year, 2025);
      expect(returnedDate!.month, 10);
      // Перевіряємо, чи змінився день. Зазвичай зсув на 40px це рівно 1 елемент назад (38px height)
      expect(returnedDate!.day, 14);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
