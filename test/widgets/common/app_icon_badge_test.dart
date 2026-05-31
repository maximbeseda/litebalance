import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/widgets/common/app_icon_badge.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppIconBadge Tests', () {
    testWidgets('1. Рендерить іконку із заданими параметрами', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppIconBadge(
            icon: Icons.star,
            color: Colors.purple,
            size: 48,
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.icon, equals(Icons.star));
      expect(iconWidget.color, equals(Colors.purple));
      expect(iconWidget.size, closeTo(48 * 0.55, 0.01));
    });

    testWidgets('2. Тло має той самий відтінок із прозорістю', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppIconBadge(icon: Icons.star, color: Colors.purple),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppIconBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.purple.withValues(alpha: 0.12)));
    });
  });
}
