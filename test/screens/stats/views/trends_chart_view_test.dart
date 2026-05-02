import 'package:coin_flow/screens/stats/views/trends_chart_view.dart'; // Переконайся, що шлях правильний
import 'package:coin_flow/screens/stats/year_summary_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
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

  const testColors = AppColorsExtension(
    bgGradientStart: Colors.blue,
    bgGradientEnd: Colors.blueAccent,
    cardBg: Colors.white,
    textMain: Colors.black,
    textSecondary: Colors.grey,
    income: Colors.green,
    expense: Colors.red,
    iconBg: Colors.grey,
    accent: Colors.orange,
  );

  // Тестові дані
  final Map<String, Map<String, Map<String, int>>> mockTrends = {
    'USD': {
      '2026-04': {'incomes': 10000, 'expenses': 5000}, // 100.00 / 50.00
      '2026-05': {'incomes': 15000, 'expenses': 8000}, // 150.00 / 80.00
    },
  };

  // Тестові дані з декількома валютами для тестування PageView
  final Map<String, Map<String, Map<String, int>>> multiCurrencyTrends = {
    'USD': {
      '2026-05': {'incomes': 15000, 'expenses': 8000},
    },
    'UAH': {
      '2026-05': {'incomes': 50000, 'expenses': 20000}, // 500.00 / 200.00
    },
  };

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Widget createTestWidget({
    required Map<String, Map<String, Map<String, int>>> trends,
  }) {
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
            theme: ThemeData(extensions: const [testColors]),
            home: Scaffold(
              body: TrendsChartView(
                trends: trends,
                colors: testColors,
                showExpenses: true,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- ТЕСТИ ---
  group('TrendsChartView UI Tests', () {
    testWidgets('Відображає порожній стан (no_data), якщо немає трендів', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(trends: {}));
      await tester.pumpAndSettle();

      expect(find.text('no_data'), findsOneWidget);
    });

    testWidgets('Відображає графік та статистику для однієї валюти', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(trends: mockTrends));

      // Використовуємо pump замість pumpAndSettle через PulsingIcon
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('history_trends'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.textContaining('\$'), findsWidgets);

      expect(find.text('income'), findsOneWidget);
      expect(find.text('stats_expenses'), findsOneWidget);
      expect(find.text('savings'), findsOneWidget);

      // Знаходимо іконку графіків
      expect(find.byIcon(Icons.insights), findsOneWidget);
    });

    testWidgets('Дозволяє свайпати між сторінками валют, якщо їх декілька', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(trends: multiCurrencyTrends));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // PageController ініціалізується з останньої сторінки (відповідно UAH)
      expect(find.text('UAH'), findsOneWidget);

      // Знаходимо PageView і гортаємо вліво (на попередню сторінку USD)
      await tester.drag(find.byType(PageView), const Offset(800.0, 0.0));

      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // Чекаємо на анімацію свайпу

      // Після свайпу має відображатись USD
      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets(
      'Відкриває YearSummaryScreen при натисканні на картку середніх показників',
      (tester) async {
        setHugeScreen(tester);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestWidget(trends: mockTrends));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Натискаємо на іконку insights, яка лежить всередині GestureDetector
        await tester.tap(find.byIcon(Icons.insights));

        // Чекаємо на анімацію навігації
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Перевіряємо, чи перейшли ми на екран підсумків
        expect(find.byType(YearSummaryScreen), findsOneWidget);
      },
    );
  });
}
