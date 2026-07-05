import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/app_modal_wrapper.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppModalWrapper Tests', () {
    testWidgets('Рендерить заголовок, контент та кнопку закриття', (
      WidgetTester tester,
    ) async {
      const testTitle = 'Налаштування профілю';
      const testContentText = 'Тут знаходяться налаштування';

      // 1. Будуємо віджет
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppModalWrapper(
            title: testTitle,
            child: Text(testContentText),
          ),
        ),
      );

      // 2. Перевіряємо заголовок
      expect(find.text(testTitle), findsOneWidget);

      // 3. Перевіряємо контент
      expect(find.text(testContentText), findsOneWidget);

      // 4. Перевіряємо іконку закриття
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Рендерить нижню кнопку, якщо вона передана (bottomButton)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: AppModalWrapper(
            title: 'Видалити категорію?',
            bottomButton: ElevatedButton(
              onPressed: () {},
              child: const Text('Підтвердити'),
            ),
            child: const Text('Ви впевнені?'),
          ),
        ),
      );

      // Перевіряємо, чи з'явилася наша кнопка
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Підтвердити'), findsOneWidget);
    });

    testWidgets('Викликає onClose при натисканні на хрестик', (
      WidgetTester tester,
    ) async {
      bool isClosed = false;

      await tester.pumpWidget(
        makeTestableWidget(
          child: AppModalWrapper(
            title: 'Тест закриття',
            onClose: () {
              isClosed = true;
            },
            child: const SizedBox(), // Порожній контент
          ),
        ),
      );

      // 1. Натискаємо на хрестик
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // 2. Перевіряємо, чи змінилася змінна
      expect(isClosed, true);
    });
  });
}
