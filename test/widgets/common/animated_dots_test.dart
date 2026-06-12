import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/animated_dots.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AnimatedDots Tests', () {
    testWidgets(
      'Анімація крапок правильно змінюється з часом (безпечний метод)',
      (WidgetTester tester) async {
        const testStyle = TextStyle(fontSize: 20, color: Colors.red);

        await tester.pumpWidget(
          makeTestableWidget(child: const AnimatedDots(style: testStyle)),
        );

        // 0 мс: початок циклу (0 крапок)
        expect(find.text(''), findsOneWidget);

        // Промотуємо на 100 мс (середина першого інтервалу 0-200) -> 0 крапок
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(''), findsOneWidget);

        // Додаємо 200 мс (загалом 300 мс, середина 200-400) -> 1 крапка
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('.'), findsOneWidget);

        // Додаємо 200 мс (загалом 500 мс, середина 400-600) -> 2 крапки
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('..'), findsOneWidget);

        // Додаємо 200 мс (загалом 700 мс, середина 600-800) -> 3 крапки
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('...'), findsOneWidget);

        // Додаємо 200 мс (загалом 900 мс, середина нового інтервалу) -> знову 0 крапок
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(''), findsOneWidget);
      },
    );

    testWidgets('Застосовує переданий TextStyle та має фіксовану ширину', (
      WidgetTester tester,
    ) async {
      const testStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

      await tester.pumpWidget(
        makeTestableWidget(child: const AnimatedDots(style: testStyle)),
      );

      // Знаходимо віджет Text
      final textFinder = find.byType(Text);
      expect(textFinder, findsOneWidget);

      // Перевіряємо, чи застосувався наш стиль
      final Text textWidget = tester.widget(textFinder);
      expect(textWidget.style?.fontSize, 24);
      expect(textWidget.style?.fontWeight, FontWeight.bold);

      // Знаходимо SizedBox-обгортку і перевіряємо жорстку ширину 24
      // find.ancestor дозволяє знайти батьківський віджет певного типу
      final sizedBoxFinder = find
          .ancestor(of: textFinder, matching: find.byType(SizedBox))
          .first;

      final SizedBox sizedBoxWidget = tester.widget(sizedBoxFinder);
      expect(sizedBoxWidget.width, 24);
    });
  });
}
