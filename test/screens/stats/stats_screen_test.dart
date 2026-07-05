import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/screens/stats/stats_screen.dart';
import 'package:litebalance/theme/app_colors_extension.dart';
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

class TestCategoryNotifier extends CategoryNotifier {
  final CategoryState mockState;
  TestCategoryNotifier(this.mockState);
  @override
  CategoryState build() => mockState;
}

class TestTransactionNotifier extends TransactionNotifier {
  final TransactionState mockState;
  TestTransactionNotifier(this.mockState);
  @override
  Future<TransactionState> build() async => mockState;
}

class TestSettingsNotifier extends SettingsNotifier {
  TestSettingsNotifier();
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: ['UAH'],
    exchangeRates: {},
    historicalCache: {},
  );
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

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget() async {
    final prefs = await SharedPreferences.getInstance();

    final catState = CategoryState(
      incomes: const [],
      accounts: const [],
      expenses: const [],
      archivedCategories: const [],
      deletedCategories: const [],
      isLoading: false,
    );

    final txState = TransactionState(
      history: const [],
      deletedHistory: const [],
      selectedMonth: DateTime.now(),
      isMigrating: false,
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(() => TestCategoryNotifier(catState)),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(txState),
        ),
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
              home: const StatsScreen(),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('StatsScreen UI Tests', () {
    testWidgets('Відображає головні елементи екрану статистики', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('statistics'), findsOneWidget);
      expect(find.text('income'), findsOneWidget);
      expect(find.text('stats_expenses'), findsOneWidget);

      expect(find.byIcon(Icons.auto_graph), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('Перемикає між Доходами та Витратами', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('income'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('stats_expenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Перемикає на перегляд Трендів (і показує порожній стан)', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.auto_graph));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('no_data'), findsOneWidget);

      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('Кнопки навігації місяцями реагують на натискання', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
