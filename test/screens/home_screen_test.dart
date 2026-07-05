// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/screens/home_screen.dart';
import 'package:litebalance/screens/transaction_screen.dart';
import 'package:litebalance/screens/category_screen.dart';
import 'package:litebalance/widgets/bottom_sheets/general_history_bottom_sheet.dart';
import 'package:litebalance/widgets/bottom_sheets/history_bottom_sheet.dart';
import 'package:litebalance/widgets/common/home_screen_skeleton.dart';
import 'package:litebalance/widgets/common/summary_header.dart';
import 'package:litebalance/widgets/dialogs/due_subscription_dialog.dart';
import 'package:litebalance/widgets/home/category_section.dart';
import 'package:litebalance/theme/app_colors_extension.dart';

// ======================================================================
// 1. ЗАГЛУШКИ (MOCKS) ТА ДАНІ
// ======================================================================

class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'history_balance': 'Баланс',
    'history_category': 'Історія {}',
    'income': 'Дохід',
    'expense': 'Витрата',
    'transfer': 'Переказ',
    'new_category': 'Нова категорія',
    'name': 'Назва',
    'currency': 'Валюта',
    'monthly_budget': 'Бюджет',
    'icons_finance': 'Фінанси',
    'outgoing_transfer': 'Вихідний',
    'top_up': 'Поповнення',
    'done': 'Готово',
  };
}

const dummyIncome = Category(
  id: 'unique_inc_1',
  name: 'Salary',
  type: CategoryType.income,
  currency: 'USD',
  amount: 0,
  icon: 0,
  bgColor: 0,
  iconColor: 0,
  isArchived: false,
  includeInTotal: true,
  sortOrder: 0,
);

const dummyAccount = Category(
  id: 'unique_acc_1',
  name: 'Bank',
  type: CategoryType.account,
  currency: 'USD',
  amount: 1000,
  icon: 0,
  bgColor: 0,
  iconColor: 0,
  isArchived: false,
  includeInTotal: true,
  sortOrder: 0,
);

const dummyExpense = Category(
  id: 'unique_exp_1',
  name: 'Food',
  type: CategoryType.expense,
  currency: 'USD',
  amount: 0,
  icon: 0,
  bgColor: 0,
  iconColor: 0,
  isArchived: false,
  includeInTotal: true,
  sortOrder: 0,
);

final dummyTx = Transaction(
  id: 'tx_123',
  fromId: 'unique_acc_1',
  toId: 'unique_exp_1',
  title: 'Test Tx',
  amount: 100,
  date: DateTime.now(),
  currency: 'USD',
  baseAmount: 100,
  baseCurrency: 'USD',
);

// ======================================================================
// 2. ШПИГУНИ (SPIES)
// ======================================================================

class SpyCategoryNotifier extends CategoryNotifier {
  final CategoryState mockState;
  bool addOrUpdateCalled = false;
  SpyCategoryNotifier(this.mockState);
  @override
  CategoryState build() => mockState;
  @override
  Future<void> addOrUpdateCategory(Category cat) async {
    addOrUpdateCalled = true;
  }

  @override
  Future<void> moveToTrash(Category cat) async {}
}

class SpyTransactionNotifier extends TransactionNotifier {
  final TransactionState mockState;
  bool addCalled = false;
  bool trashCalled = false;
  SpyTransactionNotifier(this.mockState);
  @override
  Future<TransactionState> build() async => mockState;
  @override
  Future<void> addTransactionDirectly(Transaction tx) async {
    addCalled = true;
  }

  @override
  Future<void> moveToTrash(Transaction t) async {
    trashCalled = true;
  }

  @override
  Future<void> editTransaction(
    Transaction o,
    int n,
    DateTime d, {
    int? newTargetAmount,
  }) async {}
}

class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'USD',
    selectedCurrencies: const ['USD'],
    exchangeRates: const {'USD': 1.0},
    historicalCache: const {},
  );
  @override
  int convertToBase(int amount, String fromCurrency) => amount;
}

class MockStats extends Stats with Mock {
  @override
  void build() {}
  @override
  Map<String, int> calculateTotalsForMonth(DateTime month) => const {
    'incomes': 1000,
    'expenses': 500,
  };
  @override
  Map<String, int> calculateCategoryTotalsForMonth(
    DateTime m,
    bool iE, {
    bool inBaseCurrency = true,
  }) => const {};
}

// ======================================================================
// 3. ГОЛОВНИЙ ТЕСТ
// ======================================================================

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(DateTime.now());
    await EasyLocalization.ensureInitialized();
  });

  final defaultCategoryState = CategoryState(
    incomes: const [dummyIncome],
    accounts: const [dummyAccount],
    expenses: const [dummyExpense],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  final defaultTransactionState = TransactionState(
    history: [dummyTx],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );

  Widget createTestWidget({
    SpyCategoryNotifier? catNotifier,
    SpyTransactionNotifier? txNotifier,
  }) {
    return ProviderScope(
      overrides: [
        categoryProvider.overrideWith(
          () => catNotifier ?? SpyCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => txNotifier ?? SpyTransactionNotifier(defaultTransactionState),
        ),
        subscriptionProvider.overrideWith(() => SubscriptionNotifier()),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        statsProvider.overrideWith(() => MockStats()),
        homeScreenControllerProvider.overrideWith(() => HomeScreenController()),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: const _MockAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              // Вимикаємо Hero, щоб не було конфліктів тегів
              navigatorObservers: [HeroController()],
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData(
                extensions: const [
                  AppColorsExtension(
                    bgGradientStart: Colors.blue,
                    bgGradientEnd: Colors.blue,
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
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }

  Future<void> settleScreen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('HomeScreen Coverage - Fixed', () {
    testWidgets('onAddTap: Відкриває створення та зберігає категорію', (
      tester,
    ) async {
      final catSpy = SpyCategoryNotifier(defaultCategoryState);
      await tester.pumpWidget(createTestWidget(catNotifier: catSpy));
      await settleScreen(tester);

      final section = tester.widget<CategorySection>(
        find.byType(CategorySection).first,
      );
      section.onAddTap();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CategoryScreen), findsOneWidget);

      Navigator.pop(
        tester.element(find.byType(CategoryScreen)),
        <String, dynamic>{
          'name': 'New',
          'icon': 1,
          'amount': 100,
          'currency': 'USD',
        },
      );
      await tester.pumpAndSettle();

      // Перевіряємо, що HomeScreen викликав catNotifier.addOrUpdateCategory
      expect(catSpy.addOrUpdateCalled, true);
    });

    testWidgets('onEditTap: Режим видалення повертає статус delete', (
      tester,
    ) async {
      final catSpy = SpyCategoryNotifier(defaultCategoryState);
      await tester.pumpWidget(createTestWidget(catNotifier: catSpy));
      await settleScreen(tester);

      final section = tester.widget<CategorySection>(
        find.byType(CategorySection).at(1),
      );

      late dynamic result;
      await tester.runAsync(() async {
        final Future<dynamic> editFuture = section.onEditTap(dummyAccount);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        if (find.byType(CategoryScreen).evaluate().isNotEmpty) {
          Navigator.pop(tester.element(find.byType(CategoryScreen)), 'delete');
          result = await editFuture;
        }
      });

      // Перевіряємо, що HomeScreen коректно повернув рядок 'delete' назад у секцію
      expect(result, 'delete');
      // Перевіряємо, що при 'delete' категорія НЕ намагалася оновитися як Map
      expect(catSpy.addOrUpdateCalled, false);
    });

    testWidgets('onTransfer: Перевірка створення транзакції переказу', (
      tester,
    ) async {
      final txSpy = SpyTransactionNotifier(defaultTransactionState);
      await tester.pumpWidget(createTestWidget(txNotifier: txSpy));
      await settleScreen(tester);

      final section = tester.widget<CategorySection>(
        find.byType(CategorySection).at(1),
      );
      section.onTransfer(dummyAccount, dummyExpense);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TransactionScreen), findsOneWidget);

      Navigator.pop(
        tester.element(find.byType(TransactionScreen)),
        <String, dynamic>{
          'amount': 50,
          'targetAmount': null,
          'date': DateTime.now(),
          'comment': 'test transfer',
        },
      );
      await tester.pumpAndSettle();

      // Перевіряємо, що HomeScreen викликав txNotifier.addTransactionDirectly
      expect(txSpy.addCalled, true);
    });

    testWidgets(
      'onDelete Transaction: Перевірка видалення транзакції через історію',
      (tester) async {
        final txSpy = SpyTransactionNotifier(defaultTransactionState);
        await tester.pumpWidget(createTestWidget(txNotifier: txSpy));
        await settleScreen(tester);

        // Відкриваємо історію категорій
        final section = tester.widget<CategorySection>(
          find.byType(CategorySection).at(1),
        );
        section.onHistoryTap(dummyAccount);
        await tester.pumpAndSettle();

        final historySheet = tester.widget<HistoryBottomSheet>(
          find.byType(HistoryBottomSheet),
        );

        // Викликаємо видалення транзакції (це в HomeScreen.dart)
        await historySheet.onDelete(dummyTx);

        // Перевіряємо, що HomeScreen смикнув txNotifier.moveToTrash
        expect(txSpy.trashCalled, true);
      },
    );
  });
}
