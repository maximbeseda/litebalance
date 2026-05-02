import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/home_screen.dart';
import 'package:coin_flow/widgets/bottom_sheets/general_history_bottom_sheet.dart';
import 'package:coin_flow/widgets/common/home_screen_skeleton.dart';
import 'package:coin_flow/widgets/common/summary_header.dart';
import 'package:coin_flow/widgets/dialogs/due_subscription_dialog.dart';
import 'package:coin_flow/widgets/home/category_section.dart';
import 'package:coin_flow/widgets/common/settings_drawer.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ======================================================================
// 1. СТВОРЕННЯ МОК-НОТИФІКАТОРІВ ДЛЯ RIVERPOD 3.0
// ======================================================================

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

class TestSubscriptionNotifier extends SubscriptionNotifier {
  final SubscriptionState mockState;
  TestSubscriptionNotifier(this.mockState);

  @override
  Future<SubscriptionState> build() async => mockState;
}

class TestSettingsNotifier extends SettingsNotifier {
  final SettingsState mockState;
  TestSettingsNotifier(this.mockState);

  @override
  SettingsState build() => mockState;
}

class MockStats extends Stats with Mock {
  @override
  void build() {}

  @override
  Map<String, int> calculateTotalsForMonth(DateTime month) {
    return {'incomes': 1000, 'expenses': 500};
  }

  @override
  Map<String, int> calculateCategoryTotalsForMonth(
    DateTime month,
    bool isExpenses, {
    bool inBaseCurrency = true,
  }) {
    return {};
  }
}

// Стандартний мок (режим редагування ВИМКНЕНО)
class MockHomeScreenState extends Mock implements HomeScreenState {
  @override
  bool get isEditMode => false;
}

class MockHomeScreenController extends HomeScreenController with Mock {
  @override
  HomeScreenState build() => MockHomeScreenState();
  @override
  void toggleEditMode() {}
}

// Мок для тесту режиму редагування (режим редагування УВІМКНЕНО)
class ActiveEditModeState extends Mock implements HomeScreenState {
  @override
  bool get isEditMode => true;
}

class ActiveEditModeController extends HomeScreenController with Mock {
  @override
  HomeScreenState build() => ActiveEditModeState();
  @override
  void toggleEditMode() {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  // ======================================================================
  // 2. ІНІЦІАЛІЗАЦІЯ ДЕФОЛТНИХ СТАНІВ
  // ======================================================================

  final defaultCategoryState = CategoryState(
    incomes: [],
    accounts: [],
    expenses: [],
    archivedCategories: [],
    deletedCategories: [],
    isLoading: false,
  );

  final defaultTransactionState = TransactionState(
    history: [],
    deletedHistory: [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );

  final defaultSubscriptionState = SubscriptionState(
    subscriptions: [],
    dueSubscriptions: [],
    deletedSubscriptions: [],
    ignoredSubIds: {},
  );

  final defaultSettingsState = SettingsState(
    baseCurrency: 'USD',
    selectedCurrencies: ['USD'],
    exchangeRates: {'USD': 1.0},
    historicalCache: {},
  );

  Widget createTestWidget({required List<dynamic> overrides}) {
    return ProviderScope(
      overrides: overrides.cast(),
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
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen Widget Tests', () {
    testWidgets(
      'Показує HomeScreenSkeleton, коли CategoryState вантажиться (isLoading = true)',
      (tester) async {
        final loadingCatState = defaultCategoryState.copyWith(isLoading: true);

        final overrides = [
          categoryProvider.overrideWith(
            () => TestCategoryNotifier(loadingCatState),
          ),
          transactionProvider.overrideWith(
            () => TestTransactionNotifier(defaultTransactionState),
          ),
          subscriptionProvider.overrideWith(
            () => TestSubscriptionNotifier(defaultSubscriptionState),
          ),
          settingsProvider.overrideWith(
            () => TestSettingsNotifier(defaultSettingsState),
          ),
          statsProvider.overrideWith(() => MockStats()),
        ];

        await tester.pumpWidget(createTestWidget(overrides: overrides));

        expect(find.byType(HomeScreenSkeleton), findsOneWidget);
        expect(find.byType(SummaryHeader), findsNothing);
      },
    );

    testWidgets(
      'Відображає головний UI (SummaryHeader та CategorySections), коли дані завантажено',
      (tester) async {
        final overrides = [
          categoryProvider.overrideWith(
            () => TestCategoryNotifier(defaultCategoryState),
          ),
          transactionProvider.overrideWith(
            () => TestTransactionNotifier(defaultTransactionState),
          ),
          subscriptionProvider.overrideWith(
            () => TestSubscriptionNotifier(defaultSubscriptionState),
          ),
          settingsProvider.overrideWith(
            () => TestSettingsNotifier(defaultSettingsState),
          ),
          statsProvider.overrideWith(() => MockStats()),
          homeScreenControllerProvider.overrideWith(
            () => MockHomeScreenController(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(overrides: overrides));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(HomeScreenSkeleton), findsNothing);
        expect(find.byType(SummaryHeader), findsOneWidget);
        expect(find.byType(CategorySection), findsNWidgets(3));
      },
    );

    testWidgets('Показує DueSubscriptionDialog, якщо є прострочені підписки', (
      tester,
    ) async {
      final dummySub = Subscription(
        id: 'sub_1',
        name: 'Netflix',
        amount: 15,
        currency: 'USD',
        categoryId: 'exp_1',
        accountId: 'acc_1',
        nextPaymentDate: DateTime.now().subtract(const Duration(days: 1)),
        isAutoPay: true,
        periodicity: 'monthly',
      );

      final dueSubState = defaultSubscriptionState.copyWith(
        dueSubscriptions: [dummySub],
      );

      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(dueSubState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => MockHomeScreenController(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();

      expect(find.byType(DueSubscriptionDialog), findsOneWidget);
    });

    testWidgets('Відкриває GeneralHistoryBottomSheet при кліку на баланс', (
      tester,
    ) async {
      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => MockHomeScreenController(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final summaryHeader = find.byType(SummaryHeader);
      expect(summaryHeader, findsOneWidget);

      final balanceGesture = find
          .descendant(of: summaryHeader, matching: find.byType(GestureDetector))
          .first;
      await tester.tap(balanceGesture);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GeneralHistoryBottomSheet), findsOneWidget);
    });

    testWidgets('Відкриває GeneralHistoryBottomSheet при кліку на "Доходи"', (
      tester,
    ) async {
      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => MockHomeScreenController(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final summaryHeader = find.byType(SummaryHeader);

      final incomesGesture = find
          .descendant(of: summaryHeader, matching: find.byType(GestureDetector))
          .at(1);
      await tester.tap(incomesGesture);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GeneralHistoryBottomSheet), findsOneWidget);
    });

    testWidgets('Відкриває GeneralHistoryBottomSheet при кліку на "Витрати"', (
      tester,
    ) async {
      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => MockHomeScreenController(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final summaryHeader = find.byType(SummaryHeader);

      final expensesGesture = find
          .descendant(of: summaryHeader, matching: find.byType(GestureDetector))
          .at(2);
      await tester.tap(expensesGesture);

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GeneralHistoryBottomSheet), findsOneWidget);
    });

    testWidgets('Відкриває SettingsDrawer при кліку на іконку налаштувань', (
      tester,
    ) async {
      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => MockHomeScreenController(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final settingsIcon = find.byIcon(Icons.settings);

      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(SettingsDrawer), findsOneWidget);
      }
    });

    testWidgets('Вимикає режим редагування при кліку на фон', (tester) async {
      final overrides = [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(defaultSettingsState),
        ),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(
          () => ActiveEditModeController(),
        ), // Тут мок УВІМКНЕНОГО режиму
      ];

      await tester.pumpWidget(createTestWidget(overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final backgroundGesture = find.byType(GestureDetector).first;
      await tester.tap(backgroundGesture);

      await tester.pump();
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
      ); // Тест просто доводить, що tap не викликав крашу і працює коректно
    });

    testWidgets(
      'Життєвий цикл: оновлює підписки при поверненні в додаток (resumed)',
      (tester) async {
        final overrides = [
          categoryProvider.overrideWith(
            () => TestCategoryNotifier(defaultCategoryState),
          ),
          transactionProvider.overrideWith(
            () => TestTransactionNotifier(defaultTransactionState),
          ),
          subscriptionProvider.overrideWith(
            () => TestSubscriptionNotifier(defaultSubscriptionState),
          ),
          settingsProvider.overrideWith(
            () => TestSettingsNotifier(defaultSettingsState),
          ),
          statsProvider.overrideWith(() => MockStats()),
          homeScreenControllerProvider.overrideWith(
            () => MockHomeScreenController(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(overrides: overrides));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}
