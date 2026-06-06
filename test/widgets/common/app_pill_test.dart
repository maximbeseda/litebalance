import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/widgets/common/app_pill.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppPill Tests', () {
    testWidgets('1. Відображає текст із заданим кольором', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppPill(text: 'USD', color: Colors.teal),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('USD'));
      expect(textWidget.style?.color, equals(Colors.teal));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('2. Має фіксований розмір і напівпрозоре тло', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppPill(
            text: 'EN',
            color: Colors.indigo,
            width: 48,
            height: 30,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppPill),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, equals(48));
      expect(container.constraints?.maxHeight, equals(30));

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.indigo.withValues(alpha: 0.12)));
    });
  });
}
