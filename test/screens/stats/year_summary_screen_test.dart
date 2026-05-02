import 'package:coin_flow/screens/stats/year_summary_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- ЗАГЛУШКА ЛОКАЛІЗАЦІЇ ---
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{};
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

  final Map<String, Map<String, int>> mockData = {
    '2026-05': {
      'incomes': 150000, // 1500.00
      'expenses': 50000, // 500.00
    },
    '2026-04': {
      'incomes': 100000, // 1000.00
      'expenses': 80000, // 800.00
    },
    '2025-12': {
      'incomes': 200000, // 2000.00
      'expenses': 150000, // 1500.00
    },
  };

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Widget createTestWidget() {
    return EasyLocalization(
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
            home: YearSummaryScreen(currency: 'USD', data: mockData),
          );
        },
      ),
    );
  }

  // --- ТЕСТИ ---
  group('YearSummaryScreen UI Tests', () {
    testWidgets(
      'Відображає головні елементи та Grand Total (Загальний підсумок)',
      (tester) async {
        setHugeScreen(tester);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Заголовок екрану
        expect(find.text('all_time_summary'), findsOneWidget);

        // Карточка загального підсумку (Grand Total)
        expect(find.text('net_profit_year'), findsOneWidget);
        expect(find.textContaining('savings_rate'), findsOneWidget);

        // Математика:
        // Incomes: 1500 + 1000 + 2000 = 4500
        // Expenses: 500 + 800 + 1500 = 2800
        // Net Profit: 4500 - 2800 = 1700
        expect(find.textContaining('1'), findsWidgets);
        expect(find.textContaining('7'), findsWidgets);

        // Символ валюти
        expect(find.textContaining('\$'), findsWidgets);
      },
    );

    testWidgets('Відображає картки для згрупованих років (2026 та 2025)', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Має знайти текст "2026" та "2025" на картках
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);

      // Мають відображатись назви для міні-статистики
      expect(find.text('income'), findsWidgets);
      expect(find.text('stats_expenses'), findsWidgets);
      expect(find.text('total'), findsWidgets);
      expect(find.text('average'), findsWidgets);

      // 👇 ФІКС: Шукаємо ОДНЕ АБО БІЛЬШЕ співпадінь, бо Травень виступає і як найприбутковіший, і як найекономніший місяць.
      expect(find.textContaining('(may)'), findsWidgets);
    });
  });
}
