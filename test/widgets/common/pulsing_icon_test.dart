import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/pulsing_icon.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('PulsingIcon Tests', () {
    testWidgets(
      '1. Рендерить іконку з правильними параметрами (icon, color, size)',
      (WidgetTester tester) async {
        const testIcon = Icons.favorite;
        const testColor = Colors.red;
        const testSize = 30.0;

        await tester.pumpWidget(
          makeTestableWidget(
            child: const PulsingIcon(
              icon: testIcon,
              color: testColor,
              size: testSize,
            ),
          ),
        );

        // Знаходимо саму іконку
        final iconFinder = find.byType(Icon);
        expect(iconFinder, findsOneWidget);

        final iconWidget = tester.widget<Icon>(iconFinder);

        // Перевіряємо, чи прокинулися всі параметри
        expect(iconWidget.icon, equals(testIcon));
        expect(iconWidget.color, equals(testColor));
        expect(iconWidget.size, equals(testSize));
      },
    );

    testWidgets('2. Анімація змінює масштаб та прозорість з часом', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const PulsingIcon(icon: Icons.star, color: Colors.yellow),
        ),
      );

      // Для перевірки математики анімації найпростіше відстежувати віджет Opacity
      final opacityFinder = find
          .descendant(
            of: find.byType(PulsingIcon),
            matching: find.byType(Opacity),
          )
          .first;

      double getOpacity() => tester.widget<Opacity>(opacityFinder).opacity;

      // КРОК 1: Початок (0 мс)
      // opacity = 1.0 - (0.0 * 0.3) = 1.0
      expect(getOpacity(), closeTo(1.0, 0.01));

      // КРОК 2: Середина анімації (600 мс)
      // opacity = 1.0 - (0.5 * 0.3) = 0.85
      await tester.pump(const Duration(milliseconds: 600));
      expect(getOpacity(), closeTo(0.85, 0.05));

      // КРОК 3: Пік анімації (1200 мс)
      // opacity = 1.0 - (1.0 * 0.3) = 0.70
      await tester.pump(const Duration(milliseconds: 600));
      expect(getOpacity(), closeTo(0.70, 0.01));

      // КРОК 4: Повернення назад (1800 мс)
      // Оскільки стоїть repeat(reverse: true), анімація йде у зворотний бік
      // На позначці 1800 мс opacity знову має бути близько 0.85
      await tester.pump(const Duration(milliseconds: 600));
      expect(getOpacity(), closeTo(0.85, 0.05));
    });
  });
}
