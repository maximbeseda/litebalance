import 'package:coin_flow/screens/lock_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Допоміжна функція для уникнення помилок розміру екрана
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  // Створення тестового середовища (без Riverpod, оскільки екран його не потребує)
  Widget createTestWidget({required bool isSetupMode}) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [
          AppColorsExtension(
            bgGradientStart: Colors.blue,
            bgGradientEnd: Colors.blueAccent,
            cardBg: Colors.white,
            textMain: Colors.black,
            textSecondary: Colors.grey,
            income: Colors.green,
            expense: Colors.red,
            iconBg: Colors.grey,
            accent: Colors.orange,
          ),
        ],
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: LockScreen(isSetupMode: isSetupMode),
    );
  }

  group('LockScreen UI Tests', () {
    testWidgets('Відображає режим входу (auth mode) за замовчуванням', (
      tester,
    ) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(isSetupMode: false));
      await tester.pumpAndSettle();

      // У тестовому середовищі без перекладів текст буде дорівнювати ключу
      expect(find.text('enter_pin'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Кнопки скасування не повинно бути в режимі входу
      expect(find.text('cancel'), findsNothing);
    });

    testWidgets('Відображає режим створення ПІН-коду та реагує на ввід', (
      tester,
    ) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(isSetupMode: true));
      await tester.pumpAndSettle();

      // Спочатку заголовок "Створити ПІН"
      expect(find.text('create_pin'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget); // Кнопка Скасувати присутня

      // Імітуємо введення 4 цифр ('1', '2', '3', '4')
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('4'));

      // Чекаємо 150мс (як прописано у логіці _processPin вашого екрану)
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Після введення 4 цифр заголовок має змінитись на "Підтвердити ПІН"
      expect(find.text('confirm_pin'), findsOneWidget);
    });

    testWidgets('Кнопка Backspace працює коректно', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(isSetupMode: true));
      await tester.pumpAndSettle();

      // Вводимо '1', потім стираємо
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // Вводимо ще раз 4 цифри
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Якщо Backspace спрацював, то зараз ми ввели рівно 4 цифри і перейшли до підтвердження
      expect(find.text('confirm_pin'), findsOneWidget);
    });
  });
}
