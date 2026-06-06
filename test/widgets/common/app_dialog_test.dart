import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/widgets/common/app_dialog.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppDialog Tests', () {
    testWidgets('1. confirm повертає true при підтвердженні', (tester) async {
      bool? result;
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AppDialog.confirm(
                  context,
                  title: 'Заголовок',
                  message: 'Опис дії',
                  confirmText: 'OK',
                  cancelText: 'Скасувати',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Заголовок'), findsOneWidget);
      expect(find.text('Опис дії'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('2. confirm повертає false при скасуванні', (tester) async {
      bool? result;
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AppDialog.confirm(
                  context,
                  title: 'Заголовок',
                  confirmText: 'OK',
                  cancelText: 'Скасувати',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скасувати'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('3. destructive показує іконку попередження', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppDialog.destructive(
                context,
                title: 'Видалити?',
                confirmText: 'Видалити',
                cancelText: 'Ні',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Видалити?'), findsOneWidget);
    });
  });
}
