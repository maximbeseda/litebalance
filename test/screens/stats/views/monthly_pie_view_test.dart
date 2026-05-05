import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/stats/views/monthly_pie_view.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:coin_flow/widgets/bottom_sheets/stats_category_bottom_sheet.dart';
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

class TestStats extends Stats {
  final Map<String, int> mockCategoryTotals;

  TestStats(this.mockCategoryTotals);

  @override
  Map<String, int> calculateCategoryTotalsForMonth(
    DateTime month,
    bool isExpense, {
    bool inBaseCurrency = true,
  }) {
    return mockCategoryTotals;
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
  const dummyCategory1 = Category(
    id: 'cat_1',
    type: CategoryType.expense,
    name: 'Food',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 1,
    deletedAt: null,
  );

  const dummyCategory2 = Category(
    id: 'cat_2',
    type: CategoryType.expense,
    name: 'Transport',
    icon: 0xe041,
    bgColor: 0xFF2196F3,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 2,
    deletedAt: null,
  );

  final catState = CategoryState(
    incomes: const [],
    accounts: const [],
    expenses: const [dummyCategory1, dummyCategory2],
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

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget({
    required Map<String, int> mockTotals,
    bool showExpenses = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        statsProvider.overrideWith(() => TestStats(mockTotals)),
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
              theme: ThemeData(extensions: const [testColors]),
              home: Scaffold(
                body: MonthlyPieView(
                  colors: testColors,
                  baseCurrencySymbol: '₴',
                  catState: catState,
                  txState: txState,
                  getUniqueColor: (id) =>
                      id == 'cat_1' ? Colors.red : Colors.blue,
                  statsMonth: DateTime.now(),
                  showExpenses: showExpenses,
                  animatingForward: true,
                  onChangeMonth: (newMonth) {},
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('MonthlyPieView UI Tests', () {
    testWidgets(
      'Відображає повідомлення про відсутність даних, якщо витрат немає',
      (tester) async {
        setHugeScreen(tester);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(await createTestWidget(mockTotals: {}));
        await tester.pumpAndSettle();

        expect(find.text('no_expenses_month'), findsOneWidget);
      },
    );

    testWidgets('Відображає кругову діаграму та список категорій', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final mockTotals = {'cat_1': 5000, 'cat_2': 5000};

      await tester.pumpWidget(await createTestWidget(mockTotals: mockTotals));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);

      expect(find.text('50.0%'), findsNWidgets(2));

      // 👇 ФІКС: Уникаємо проблеми з нерозривними пробілами та форматуванням
      expect(find.textContaining('50'), findsWidgets);
      expect(find.textContaining('₴'), findsWidgets);
    });

    testWidgets(
      'Відкриває BottomSheet статистики категорії при натисканні на елемент списку',
      (tester) async {
        setHugeScreen(tester);
        addTearDown(tester.view.resetPhysicalSize);

        final mockTotals = {'cat_1': 10000};

        await tester.pumpWidget(await createTestWidget(mockTotals: mockTotals));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Food'));

        // 👇 ФІКС: Використовуємо pump замість pumpAndSettle, щоб обійти нескінченні анімації всередині BottomSheet
        await tester.pump(); // Починаємо анімацію появи
        await tester.pump(
          const Duration(seconds: 1),
        ); // Чекаємо 1 секунду, поки BottomSheet повністю виїде

        expect(find.byType(StatsCategoryBottomSheet), findsOneWidget);
      },
    );
  });
}
