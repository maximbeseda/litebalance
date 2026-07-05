import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/app_snackbar.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppSnackbar Tests', () {
    testWidgets('1. success показує снекбар із повідомленням та галочкою', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackbar.success(context, 'Готово'),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('2. error використовує іконку помилки', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackbar.error(context, 'Помилка'),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Помилка'), findsOneWidget);
    });

    testWidgets('3. Повторний виклик прибирає попередній снекбар', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppSnackbar.info(context, 'Інфо'),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
