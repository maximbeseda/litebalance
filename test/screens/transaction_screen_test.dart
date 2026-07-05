import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/screens/transaction_screen.dart';
import 'package:litebalance/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

// ==========================================
// 1. ЗАГЛУШКА ЛОКАЛІЗАЦІЇ
// ==========================================
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{
      'add_note': 'Add note',
      'updating_rates': 'Updating...',
      'rate_unavailable': 'Unavailable',
      'enter_manually': 'Enter manually',
      'done': 'Done',
      'yesterday': 'Yesterday',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
    };
  }
}

// ==========================================
// 2. МОК-НОТИФІКАТОРИ
// ==========================================
class TestSettingsNotifier extends SettingsNotifier {
  TestSettingsNotifier();

  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH', 'USD'],
    // 1 UAH = 0.025 USD -> 1 USD = 40 UAH
    exchangeRates: const {'USD': 0.025, 'UAH': 1.0},
    historicalCache: const {},
  );

  @override
  Future<double?> getRateForDate(String currency, DateTime date) async {
    if (currency == 'USD') return 0.025;
    return 1.0;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void setHugeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // --- ДАНІ БАЗИ ---
  const uahWallet = Category(
    id: 'acc_1',
    type: CategoryType.account,
    name: 'UAH Wallet',
    icon: 0xe041,
    bgColor: 0xFF2196F3,
    iconColor: 0xFFFFFFFF,
    amount: 1000,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
  );

  const usdWallet = Category(
    id: 'acc_2',
    type: CategoryType.account,
    name: 'USD Wallet',
    icon: 0xe041,
    bgColor: 0xFF4CAF50,
    iconColor: 0xFFFFFFFF,
    amount: 500,
    isArchived: false,
    currency: 'USD',
    includeInTotal: true,
    sortOrder: 1,
  );

  const uahExpense = Category(
    id: 'exp_1',
    type: CategoryType.expense,
    name: 'Groceries',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 2,
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<void> openTransactionScreen(
    WidgetTester tester, {
    required Category source,
    required Category target,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(() => TestSettingsNotifier()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          assetLoader: const _MockAssetLoader(),
          child: Builder(
            builder: (context) {
              return MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
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
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) {
                      return ElevatedButton(
                        onPressed: () async {
                          await Navigator.push<Map<String, dynamic>>(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => TransactionScreen(
                                source: source,
                                target: target,
                              ),
                            ),
                          );
                        },
                        child: const Text('OPEN'),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  // ==========================================
  // ТЕСТИ
  // ==========================================
  group('TransactionScreen Calculator & Logic Tests', () {
    testWidgets('1. Базова математика та збереження (Одна валюта)', (
      tester,
    ) async {
      setHugeScreen(tester);

      await openTransactionScreen(
        tester,
        source: uahWallet,
        target: uahExpense,
      );

      // Вводимо 50 + 25 = 75
      await tester.tap(find.text('5'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('0'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('+'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('5'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.textContaining('75'), findsWidgets);

      // Очищуємо 'C'
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('2. Розрахунок відсотків та видалення (Backspace)', (
      tester,
    ) async {
      setHugeScreen(tester);
      await openTransactionScreen(
        tester,
        source: uahWallet,
        target: uahExpense,
      );

      // Вводимо 200 - 10% = 180
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('-'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('%'));
      await tester.pumpAndSettle();

      expect(find.textContaining('20'), findsWidgets);

      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      expect(find.textContaining('180'), findsWidgets);

      final backspaceIcon = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.backspace || w.icon == Icons.backspace_outlined),
      );

      if (backspaceIcon.evaluate().isNotEmpty) {
        await tester.tap(backspaceIcon.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('18'), findsWidgets);
      }
    });

    testWidgets('3. Різні валюти: Зв\'язані суми (Linked Amounts)', (
      tester,
    ) async {
      setHugeScreen(tester);
      await openTransactionScreen(
        tester,
        source: usdWallet,
        target: uahExpense,
      );

      // Вводимо 10 USD (Джерело)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10'), findsWidgets);
      expect(find.textContaining('400'), findsWidgets);

      // 👇 ФІКС: Шукаємо саме число 400, щоб клікнути рівно на цільову суму
      final targetAmountBox = find.textContaining('400').first;
      await tester.tap(targetAmountBox);
      await tester.pumpAndSettle();

      // Очищуємо і вводимо 800
      await tester.tap(find.text('C'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      // Оскільки лінк розірвано, ціль: 800, а джерело ЗАЛИШИЛОСЯ 10
      expect(find.textContaining('800'), findsWidgets);
      expect(find.textContaining('10'), findsWidgets);

      // Відновлюємо зв'язок натисканням на іконку Swap
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();

      // ТЕПЕР джерело перераховується: 800 / 40 = 20
      expect(find.textContaining('20'), findsWidgets);
    });

    testWidgets('4. Десяткові дроби та edge-кейси (Double Zero)', (
      tester,
    ) async {
      setHugeScreen(tester);
      await openTransactionScreen(
        tester,
        source: uahWallet,
        target: uahExpense,
      );

      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0.5'), findsWidgets);

      await tester.tap(find.text('C'));
      await tester.pump();

      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('00'));
      await tester.pump();
      await tester.tap(find.text('00'));
      await tester.pumpAndSettle();
      expect(find.textContaining('70 000'), findsWidgets);
    });

    testWidgets('5. Додавання нотатки та перемикання клавіатур', (
      tester,
    ) async {
      setHugeScreen(tester);
      await openTransactionScreen(
        tester,
        source: uahWallet,
        target: uahExpense,
      );

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Lunch');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      // 👇 ФІКС: Перевіряємо, що TextField зник, і ми знову бачимо калькулятор
      expect(find.byType(TextField), findsNothing);
      expect(find.text('5'), findsOneWidget); // Numpad повернувся
    });
  });
}
