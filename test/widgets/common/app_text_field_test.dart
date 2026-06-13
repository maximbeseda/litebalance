import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/app_text_field.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AppTextField Tests', () {
    testWidgets(
      'Рендерить лейбл, приймає введення тексту та викликає onChanged',
      (WidgetTester tester) async {
        final controller = TextEditingController();
        String changedValue = '';

        // 1. Будуємо віджет
        await tester.pumpWidget(
          makeTestableWidget(
            child: AppTextField(
              label: 'Введіть суму',
              controller: controller,
              onChanged: (val) => changedValue = val,
            ),
          ),
        );

        // 2. Перевіряємо наявність лейбла
        expect(find.text('Введіть суму'), findsOneWidget);

        // 3. Знаходимо сам TextField
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // 4. Вводимо текст
        await tester.enterText(textFieldFinder, '500');
        await tester.pump();

        // 5. Перевіряємо, чи оновився контролер і чи спрацював onChanged
        expect(controller.text, '500');
        expect(changedValue, '500');
      },
    );

    testWidgets('Відображає текст помилки (errorText)', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      const errorMessage = 'Поле не може бути порожнім';

      await tester.pumpWidget(
        makeTestableWidget(
          child: AppTextField(
            label: 'Назва',
            controller: controller,
            errorText: errorMessage,
          ),
        ),
      );

      // Перевіряємо, чи з'явився текст помилки
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets(
      'Застосовує збільшений шрифт (isLarge) та відображає іконки/суфікси',
      (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          makeTestableWidget(
            child: AppTextField(
              label: '', // Без лейбла
              controller: controller,
              isLarge: true,
              suffixText: 'UAH',
              prefixIcon: const Icon(Icons.attach_money),
            ),
          ),
        );

        // Перевіряємо наявність суфікса та іконки
        expect(find.text('UAH'), findsOneWidget);
        expect(find.byIcon(Icons.attach_money), findsOneWidget);

        // Дістаємо віджет TextField і перевіряємо його стиль
        final textFieldWidget = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textFieldWidget.style?.fontSize, 28);
        expect(textFieldWidget.style?.fontWeight, FontWeight.w800);
      },
    );
  });
}
