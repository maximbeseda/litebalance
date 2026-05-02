import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/transaction_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- ЗАГЛУШКА ЛОКАЛІЗАЦІЇ ---
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{};
  }
}

// --- МОК-НОТИФІКАТОРИ ---
class TestSettingsNotifier extends SettingsNotifier {
  TestSettingsNotifier();

  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: ['UAH', 'USD'],
    // 👇 ФІКС: Курс долара відносно гривні (1 UAH = 0.025 USD)
    exchangeRates: {'USD': 0.025, 'UAH': 1.0},
    historicalCache: {},
  );

  @override
  Future<double?> getRateForDate(String currency, DateTime date) async {
    // 👇 ФІКС: Повертаємо 0.025, щоб розрахунок (1 / 0.025) дав рівно 40.0
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
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
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
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
    deletedAt: null,
  );

  const usdWallet = Category(
    id: 'acc_2',
    type: CategoryType.account,
    name: 'USD Wallet',
    icon: 0xe041,
    bgColor: 0xFF4CAF50,
    iconColor: 0xFFFFFFFF,
    amount: 500,
    budget: null,
    isArchived: false,
    currency: 'USD',
    includeInTotal: true,
    sortOrder: 1,
    deletedAt: null,
  );

  const uahExpense = Category(
    id: 'exp_1',
    type: CategoryType.expense,
    name: 'Groceries',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 2,
    deletedAt: null,
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget({
    required Category source,
    required Category target,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
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
              localizationsDelegates: [
                ...context.localizationDelegates,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
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
              home: TransactionScreen(source: source, target: target),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('TransactionScreen UI Tests', () {
    testWidgets('Відображає одне поле вводу, якщо валюти збігаються', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(source: uahWallet, target: uahExpense),
      );
      await tester.pumpAndSettle();

      expect(find.text('UAH Wallet'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      expect(find.textContaining('₴'), findsWidgets);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('Відображає два поля вводу та курс обміну, якщо валюти різні', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(source: usdWallet, target: uahExpense),
      );
      await tester.pumpAndSettle();

      expect(find.text('USD Wallet'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      expect(find.textContaining('\$'), findsWidgets);
      expect(find.textContaining('₴'), findsWidgets);

      // Тепер математика додатку розрахує 1.0 / 0.025 = 40 і знайде цей текст!
      expect(find.textContaining('1 \$ = 40 ₴'), findsOneWidget);
    });

    testWidgets('Реагує на введення цифр з Numpad', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(source: uahWallet, target: uahExpense),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('5'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('0'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('Перемикає Numpad на текстове поле коментаря', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(source: uahWallet, target: uahExpense),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();

      expect(find.text('add_note'), findsOneWidget);
      expect(find.text('5'), findsNothing);

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });
  });
}
