import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/app_empty_state.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppEmptyState Tests', () {
    testWidgets('1. Показує ілюстрацію, заголовок та підзаголовок', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const AppEmptyState(
            icon: Icons.inbox,
            title: 'Порожньо',
            subtitle: 'Тут поки нічого немає',
            animate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyIllustration), findsOneWidget);
      expect(find.text('Порожньо'), findsOneWidget);
      expect(find.text('Тут поки нічого немає'), findsOneWidget);
    });

    testWidgets('2. Відображає кнопку-дію, коли вона задана', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: AppEmptyState(
            icon: Icons.inbox,
            title: 'Порожньо',
            animate: false,
            action: ElevatedButton(
              onPressed: () {},
              child: const Text('Додати'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Додати'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('3. EmptyIllustration малює CustomPaint з іконкою', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const EmptyIllustration(
            icon: Icons.delete_outline,
            color: Colors.teal,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.icon, equals(Icons.delete_outline));
      expect(iconWidget.color, equals(Colors.teal));
    });
  });
}
