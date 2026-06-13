import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/rolling_digit.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('RollingDigit Tests', () {
    const testStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

    testWidgets(
      '1. Відображає звичайний текст для нецифрових символів (кома, пробіл, знак)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            child: const RollingDigit(char: ',', style: testStyle),
          ),
        );

        // Має використовуватися AnimatedSwitcher
        expect(find.byType(AnimatedSwitcher), findsOneWidget);

        // Має бути простий текст із переданим символом
        expect(find.text(','), findsOneWidget);

        // Не повинно бути барабана (AnimatedSlide відсутній)
        expect(find.byType(AnimatedSlide), findsNothing);
      },
    );

    testWidgets('2. Рендерить барабан (всі цифри 0-9) для цифрових символів', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const RollingDigit(char: '5', style: testStyle),
        ),
      );

      // Має бути AnimatedSlide та ClipRect для обрізки видимої зони
      expect(find.byType(AnimatedSlide), findsOneWidget);
      expect(find.byType(ClipRect), findsOneWidget);

      // Всередині барабана мають бути відрендерені всі цифри від 0 до 9
      for (int i = 0; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
    });

    testWidgets(
      '3. AnimatedSlide розраховує правильний зсув (offset) залежно від цифри',
      (WidgetTester tester) async {
        // КРОК 1: Рендеримо цифру 3
        await tester.pumpWidget(
          makeTestableWidget(
            child: const RollingDigit(char: '3', style: testStyle),
          ),
        );

        AnimatedSlide slideWidget = tester.widget(find.byType(AnimatedSlide));

        // За вашою логікою: offset = Offset(0, -digit / 10)
        // Для цифри 3 зсув по Y має бути -0.3
        expect(slideWidget.offset, equals(const Offset(0, -0.3)));

        // КРОК 2: Змінюємо цифру на 8 (симулюємо оновлення балансу)
        await tester.pumpWidget(
          makeTestableWidget(
            child: const RollingDigit(char: '8', style: testStyle),
          ),
        );

        // Даємо час на завершення анімації (duration: 600ms)
        await tester.pumpAndSettle();

        // Отримуємо оновлений віджет
        slideWidget = tester.widget(find.byType(AnimatedSlide));

        // Для цифри 8 зсув по Y має бути -0.8
        expect(slideWidget.offset, equals(const Offset(0, -0.8)));
      },
    );

    testWidgets(
      '4. Використовує TextBaseline.alphabetic для правильного вирівнювання',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            child: const RollingDigit(char: '7', style: testStyle),
          ),
        );

        // Знаходимо віджет Baseline
        final baselineWidget = tester.widget<Baseline>(find.byType(Baseline));

        // Перевіряємо, чи застосовано правильний тип базової лінії
        expect(baselineWidget.baselineType, equals(TextBaseline.alphabetic));
        // Baseline offset має бути вирахуваний TextPainter'ом (більше за 0)
        expect(baselineWidget.baseline, greaterThan(0));
      },
    );
  });
}
