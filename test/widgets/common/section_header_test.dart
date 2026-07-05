import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/section_header.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('SectionHeader Tests', () {
    testWidgets('1. Відображає заголовок ВЕЛИКИМИ літерами', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(child: const SectionHeader('Security')),
      );

      expect(find.text('SECURITY'), findsOneWidget);
    });

    testWidgets('2. Має розрядку та жирне накреслення', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(child: const SectionHeader('test')),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
      expect(textWidget.style?.letterSpacing, equals(1.2));
    });
  });
}
