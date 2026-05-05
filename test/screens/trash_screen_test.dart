import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/trash_screen.dart';
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

class TestCategoryNotifier extends CategoryNotifier {
  final CategoryState mockState;
  TestCategoryNotifier(this.mockState);

  @override
  CategoryState build() => mockState;

  @override
  Future<void> emptyTrashOrArchive(Category cat) async {}

  @override
  Future<void> restoreFromTrash(Category cat) async {}
}

class TestTransactionNotifier extends TransactionNotifier {
  final TransactionState mockState;
  TestTransactionNotifier(this.mockState);

  @override
  Future<TransactionState> build() async => mockState;

  @override
  Future<void> deletePermanently(Transaction tx) async {}

  @override
  Future<void> restoreFromTrash(Transaction tx) async {}
}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  final SubscriptionState mockState;
  TestSubscriptionNotifier(this.mockState);

  @override
  Future<SubscriptionState> build() async => mockState;

  @override
  Future<void> deletePermanently(String id) async {}

  @override
  Future<void> restoreFromTrash(Subscription sub) async {}
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
  final now = DateTime.now();
  final recentDeleteDate = now.subtract(
    const Duration(days: 5),
  ); // Видалено 5 днів тому

  const dummyAccount = Category(
    id: 'acc_1',
    type: CategoryType.account,
    name: 'Wallet',
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

  final deletedCategory = Category(
    id: 'cat_del_1',
    type: CategoryType.expense,
    name: 'Deleted Expense',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 1,
    deletedAt: recentDeleteDate,
  );

  final deletedTx = Transaction(
    id: 'tx_del_1',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Deleted Tx',
    titleLower: 'deleted tx',
    date: now,
    amount: 50000, // 500.00
    currency: 'UAH',
    targetAmount: null,
    targetCurrency: null,
    baseAmount: 50000,
    baseCurrency: 'UAH',
    deletedAt: recentDeleteDate,
  );

  final deletedSub = Subscription(
    id: 'sub_del_1',
    name: 'Deleted Sub',
    amount: 1500, // 15.00
    categoryId: 'exp_1',
    accountId: 'acc_1',
    nextPaymentDate: now,
    periodicity: 'monthly',
    customIconCodePoint: null,
    isAutoPay: false,
    currency: 'UAH',
    deletedAt: recentDeleteDate,
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget({
    required CategoryState catState,
    required TransactionState txState,
    required SubscriptionState subState,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(() => TestCategoryNotifier(catState)),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(txState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(subState),
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
              home: const TrashScreen(),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('TrashScreen UI Tests', () {
    testWidgets('Відображає порожній стан, якщо кошик пустий', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final emptyCatState = CategoryState(
        incomes: const [],
        accounts: const [],
        expenses: const [],
        archivedCategories: const [],
        deletedCategories: const [],
        isLoading: false,
      );
      final emptyTxState = TransactionState(
        history: const [],
        deletedHistory: const [],
        selectedMonth: now,
        isMigrating: false,
      );
      final emptySubState = SubscriptionState(
        subscriptions: const [],
        dueSubscriptions: const [],
        ignoredSubIds: const {},
        deletedSubscriptions: const [],
      );

      await tester.pumpWidget(
        await createTestWidget(
          catState: emptyCatState,
          txState: emptyTxState,
          subState: emptySubState,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('trash'), findsOneWidget);
      expect(find.text('trash_empty'), findsOneWidget);
      // Кнопка очищення кошика (мітла) має бути відсутня
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });

    testWidgets('Відображає елементи кошика та кнопку очищення', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final catState = CategoryState(
        incomes: const [],
        accounts: [dummyAccount],
        expenses: const [],
        archivedCategories: const [],
        deletedCategories: [deletedCategory],
        isLoading: false,
      );
      final txState = TransactionState(
        history: const [],
        deletedHistory: [deletedTx],
        selectedMonth: now,
        isMigrating: false,
      );
      final subState = SubscriptionState(
        subscriptions: const [],
        dueSubscriptions: const [],
        ignoredSubIds: const {},
        deletedSubscriptions: [deletedSub],
      );

      await tester.pumpWidget(
        await createTestWidget(
          catState: catState,
          txState: txState,
          subState: subState,
        ),
      );
      await tester.pumpAndSettle();

      // Кнопка очищення кошика
      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);

      // Мають відображатись назви видалених елементів
      expect(find.text('Deleted Expense'), findsOneWidget);
      expect(find.text('Deleted Sub'), findsOneWidget);

      // Мають бути кнопки "Відновити" та "Видалити назавжди" для кожного елемента (їх має бути по 3)
      expect(find.byIcon(Icons.restore), findsNWidgets(3));
      expect(find.byIcon(Icons.delete_forever), findsNWidgets(3));
    });

    testWidgets('Відкриває діалог очищення кошика та реагує на скасування', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final catState = CategoryState(
        incomes: const [],
        accounts: const [],
        expenses: const [],
        archivedCategories: const [],
        deletedCategories: [deletedCategory],
        isLoading: false,
      );
      final txState = TransactionState(
        history: const [],
        deletedHistory: const [],
        selectedMonth: now,
        isMigrating: false,
      );
      final subState = SubscriptionState(
        subscriptions: const [],
        dueSubscriptions: const [],
        ignoredSubIds: const {},
        deletedSubscriptions: const [],
      );

      await tester.pumpWidget(
        await createTestWidget(
          catState: catState,
          txState: txState,
          subState: subState,
        ),
      );
      await tester.pumpAndSettle();

      // Тиснемо на мітлу
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();

      // Діалог має з'явитися
      expect(find.text('empty_trash_title'), findsOneWidget);
      expect(find.text('empty_trash_msg'), findsOneWidget);

      // Тиснемо скасувати
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      // Діалог має зникнути
      expect(find.text('empty_trash_title'), findsNothing);
    });
  });
}
