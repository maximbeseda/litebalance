import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/category_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class TestSettingsNotifier extends SettingsNotifier {
  final SettingsState mockState;
  TestSettingsNotifier(this.mockState);

  @override
  SettingsState build() => mockState;
}

void main() {
  final defaultSettingsState = SettingsState(
    baseCurrency: 'USD',
    selectedCurrencies: ['USD', 'EUR', 'UAH'],
    exchangeRates: {'USD': 1.0, 'EUR': 0.9, 'UAH': 40.0},
    historicalCache: {},
  );

  final overrides = [
    settingsProvider.overrideWith(
      () => TestSettingsNotifier(defaultSettingsState),
    ),
  ];

  dynamic poppedResult;

  Widget createTestWidget({Category? category, required CategoryType type}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
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
        supportedLocales: const [Locale('en'), Locale('uk')],
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('launch_btn'),
                onPressed: () async {
                  poppedResult = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CategoryScreen(category: category, type: type),
                    ),
                  );
                },
                child: const Text('Launch'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final dummyCategory = Category(
    id: 'inc_1',
    type: CategoryType.income,
    name: 'Freelance',
    icon: Icons.work.codePoint,
    amount: 500000,
    budget: 100000,
    isArchived: false,
    bgColor: Colors.green.toARGB32(),
    iconColor: Colors.white.toARGB32(),
    currency: 'EUR',
    includeInTotal: true,
    sortOrder: 0,
  );

  group('CategoryScreen Widget Tests', () {
    setUp(() {
      poppedResult = null;
    });

    testWidgets('Відображає форму для СТВОРЕННЯ нової категорії (пусті поля)', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(type: CategoryType.expense));
      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(textFields[0].controller?.text, '');
      expect(textFields[1].controller?.text, 'USD');
    });

    testWidgets(
      'Відображає форму для РЕДАГУВАННЯ існуючої категорії (заповнені поля)',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(category: dummyCategory, type: CategoryType.income),
        );
        await tester.tap(find.byKey(const Key('launch_btn')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        final textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(textFields[0].controller?.text, 'Freelance');
        expect(textFields[1].controller?.text, 'EUR');
        expect(textFields[2].controller?.text, '1 000');
      },
    );

    testWidgets('Не дає зберегти, якщо ім\'я пусте (валідція)', (tester) async {
      await tester.pumpWidget(createTestWidget(type: CategoryType.expense));
      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
      expect(poppedResult, isNull);
    });

    testWidgets('Відкриває BottomSheet і дозволяє змінити іконку', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(type: CategoryType.expense));
      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      // 👇 ВИПРАВЛЕНО: Чекаємо поки BottomSheet повністю виїде на екран
      await tester.pumpAndSettle();

      // 👇 ВИПРАВЛЕНО: Беремо перший доступний клікабельний елемент у сітці
      final firstGridItem = find
          .descendant(
            of: find.byType(SliverGrid),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(firstGridItem);
      // Чекаємо поки BottomSheet повністю сховається
      await tester.pumpAndSettle();

      expect(find.text('choose_icon'), findsNothing);
    });

    testWidgets('Відкриває BottomSheet і дозволяє змінити валюту', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(type: CategoryType.expense));
      await tester.tap(find.byKey(const Key('launch_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();

      // 👇 ВИПРАВЛЕНО: Скролимо список вниз, поки не побачимо текст 'EUR'
      await tester.dragUntilVisible(
        find.text('EUR'),
        find.byType(ListView), // Скролимо сам ListView
        const Offset(0, -300), // Рух пальцем вгору (щоб прокрутити вниз)
      );
      await tester.pumpAndSettle(); // Даємо списку зупинитися

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();

      final currencyField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(currencyField.controller?.text, 'EUR');
    });

    testWidgets(
      'Зберігає дані та повертає правильний Map (дохід/витрата -> бюджет)',
      (tester) async {
        await tester.pumpWidget(createTestWidget(type: CategoryType.income));
        await tester.tap(find.byKey(const Key('launch_btn')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'Salary');
        await tester.enterText(find.byType(TextField).at(2), '2500,50');

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(poppedResult, isA<Map<String, dynamic>>());
        final result = poppedResult as Map<String, dynamic>;

        expect(result['name'], 'Salary');
        expect(result['currency'], 'USD');
        expect(result['budget'], 250050);
        expect(result['amount'], 0);
      },
    );

    testWidgets(
      'Зберігає дані та повертає правильний Map (рахунок -> баланс)',
      (tester) async {
        await tester.pumpWidget(createTestWidget(type: CategoryType.account));
        await tester.tap(find.byKey(const Key('launch_btn')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'Monobank');
        await tester.enterText(find.byType(TextField).at(2), '500.25');

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        final result = poppedResult as Map<String, dynamic>;
        expect(result['name'], 'Monobank');
        expect(result['amount'], 50025);
        expect(result['budget'], null);
        expect(result['includeInTotal'], false);
      },
    );

    testWidgets(
      'Видалення категорії показує Dialog і повертає рядок "delete"',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(category: dummyCategory, type: CategoryType.income),
        );
        await tester.tap(find.byKey(const Key('launch_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle(); // Чекаємо відкриття Dialog

        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();

        expect(poppedResult, 'delete');
      },
    );
  });
}
