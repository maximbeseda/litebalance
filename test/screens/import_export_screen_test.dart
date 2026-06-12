import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/screens/import_export_screen.dart';
import 'package:litebalance/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. МОКИ ТА ЗАГЛУШКИ
// ==========================================

class _MockAssetLoader extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'data_management': 'Data',
    'export_csv': 'Export',
    'import_csv': 'Import',
    'export_button': 'Export Now',
    'import_button': 'Import Now',
    'export_only_filtered': 'Filtered only',
    'filter_settings': 'Filter Settings',
    'filter_all_time': 'All time',
    'filter_period': 'Period',
    'filter_tx_type': 'Type',
    'filter_type_incomes': 'Incomes',
    'filter_type_expenses': 'Expenses',
    'filter_type_transfers': 'Transfers',
    'filter_categories': 'Categories',
    'filter_all_categories': 'All categories',
    'apply': 'Apply',
    'exporting_count': '{} items',
    'exporting_all': 'All',
    'export_description': 'Desc',
    'import_description': 'Desc',
    'csv_export_headers': 'Headers',
    'outgoing_transfer': 'Outgoing',
    'top_up': 'Top Up',
    'csv_type_other': 'Other',
    'csv_deleted_category': 'Deleted',
    'export_success': 'Success',
    'export_error': 'Error',
    'import_format_error': 'Format error',
  };
}

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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  const dummyAccount = Category(
    id: 'acc_1',
    type: CategoryType.account,
    name: 'Wallet',
    icon: 0xe041,
    bgColor: 0xFF2196F3,
    iconColor: 0xFFFFFFFF,
    amount: 1000,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
  );

  const dummyIncome = Category(
    id: 'inc_1',
    type: CategoryType.income,
    name: 'Salary',
    icon: 0xe041,
    bgColor: 0xFF4CAF50,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 1,
  );

  const dummyExpense = Category(
    id: 'exp_1',
    type: CategoryType.expense,
    name: 'Food',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 2,
  );

  final dummyTx = Transaction(
    id: 'tx_1',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Test',
    date: DateTime(2026, 4, 27),
    amount: 100,
    currency: 'UAH',
    baseAmount: 100,
    baseCurrency: 'UAH',
  );

  final defaultCategoryState = CategoryState(
    incomes: const [dummyIncome],
    accounts: const [dummyAccount],
    expenses: const [dummyExpense], // 👇 Додали Expense категорію сюди
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  final defaultTransactionState = TransactionState(
    history: [dummyTx],
    deletedHistory: const [],
    selectedMonth: DateTime(2026, 4, 1),
    isMigrating: false,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: _MockAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
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
              // 👇 ДОДАНО: Бар'єр завантаження
              // Екран з'явиться ТІЛЬКИ після того, як провайдер транзакцій завантажить дані
              home: Consumer(
                builder: (context, ref, child) {
                  final txAsync = ref.watch(transactionProvider);
                  if (txAsync.isLoading || txAsync.value == null) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const ImportExportScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('ImportExportScreen Logic & UI Coverage', () {
    testWidgets('1. Перемикання фільтрації та відкриття налаштувань', (
      tester,
    ) async {
      setLargeScreen(tester);
      await tester.pumpWidget(createTestWidget());
      await tester
          .pumpAndSettle(); // Дочекаємося, поки зникне CircularProgressIndicator

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Filter Settings'), findsWidgets);

      await tester.tap(find.text('Filter Settings').last);
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
    });

    testWidgets('2. Вибір категорій у фільтрі', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter Settings').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salary'));
      await tester.pump();

      await tester.tap(find.text('Incomes'));
      await tester.pump();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsNothing);
    });

    testWidgets('3. Перевірка лічильника транзакцій при фільтрації', (
      tester,
    ) async {
      setLargeScreen(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Тепер екран гарантовано бачить 1 items, бо дочекався завантаження провайдера
      expect(find.textContaining('1 items'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter Settings').last);
      await tester.pumpAndSettle();

      // Наша транзакція (tx_1) належить до Expense, тому якщо вимкнути Expenses, вона зникне
      await tester.tap(find.text('Expenses'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Після застосування фільтра кількість елементів змінюється на 0
      expect(find.textContaining('0 items'), findsOneWidget);
    });

    testWidgets('4. Експорт показує лоадер', (tester) async {
      setLargeScreen(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Now'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
