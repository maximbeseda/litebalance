import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:litebalance/widgets/common/history_search_bar.dart';
import 'package:litebalance/providers/filter_provider.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('HistorySearchBar Tests', () {
    testWidgets(
      'Повинен показувати іконку очищення при введенні та правильно працювати з таймером',
      (WidgetTester tester) async {
        // Будуємо віджет. TextField обов'язково потребує Scaffold як предка.
        await tester.pumpWidget(
          ProviderScope(
            child: makeTestableWidget(
              child: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(
                      filterProvider,
                    ); // Тримаємо провайдер живим для тесту
                    return const HistorySearchBar();
                  },
                ),
              ),
            ),
          ),
        );

        // 1. Спочатку іконка "очистити" (Clear) не повинна відображатися
        expect(find.byIcon(Icons.close_rounded), findsNothing);

        // 2. Вводимо текст у поле
        await tester.enterText(find.byType(TextField), 'Кава');
        await tester.pump(); // Оновлюємо UI, щоб віджет перебудувався

        // 3. Тепер іконка "очистити" має з'явитися
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // ⚠️ МАГІЯ ТАЙМЕРІВ: Чекаємо 350 мілісекунд, щоб відпрацював Debounce _debounce (який у вас 300мс)
        // Це критично важливо, інакше тест завершиться з помилкою "A Timer is still pending"
        await tester.pump(const Duration(milliseconds: 350));

        // 4. Натискаємо на іконку очищення
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump(); // Оновлюємо UI

        // 5. Перевіряємо, що поле очистилося, а іконка зникла
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, '');
        expect(find.byIcon(Icons.close_rounded), findsNothing);

        // Знову чекаємо 350мс, тому що після очищення ви викликаєте _onSearchChanged(''),
        // що створює ще один таймер
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
  });
}
