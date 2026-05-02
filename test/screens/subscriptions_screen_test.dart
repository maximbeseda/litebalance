import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/subscriptions_screen.dart';
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
}

class TestSettingsNotifier extends SettingsNotifier {
  TestSettingsNotifier();
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: ['UAH', 'USD', 'EUR'],
    exchangeRates: {},
    historicalCache: {},
  );
}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  final SubscriptionState mockState;
  TestSubscriptionNotifier(this.mockState);

  @override
  Future<SubscriptionState> build() async => mockState;

  // Мокаємо метод оплати підписки, щоб тест не падав при кліку на "pay"
  @override
  Future<(bool, String)> confirmSubscriptionPayment(
    Subscription sub,
    int amount,
  ) async {
    return (true, 'Payment Successful');
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

  const dummyExpense = Category(
    id: 'exp_1',
    type: CategoryType.expense,
    name: 'Subscriptions',
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

  final defaultCategoryState = CategoryState(
    incomes: const [],
    accounts: const [dummyAccount],
    expenses: const [dummyExpense],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  // Підписка, яку НЕ треба платити (в майбутньому)
  final futureSubscription = Subscription(
    id: 'sub_future',
    name: 'Netflix',
    amount: 1500, // 15.00
    categoryId: 'exp_1',
    accountId: 'acc_1',
    nextPaymentDate: DateTime.now().add(const Duration(days: 10)),
    periodicity: 'monthly',
    customIconCodePoint: null,
    isAutoPay: true,
    currency: 'USD',
    deletedAt: null,
  );

  // Підписка, яку ТРЕБА платити (прострочена або сьогодні)
  final dueSubscription = Subscription(
    id: 'sub_due',
    name: 'Spotify',
    amount: 999, // 9.99
    categoryId: 'exp_1',
    accountId: 'acc_1',
    nextPaymentDate: DateTime.now().subtract(const Duration(days: 1)),
    periodicity: 'monthly',
    customIconCodePoint: null,
    isAutoPay: false,
    currency: 'USD',
    deletedAt: null,
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget({required SubscriptionState subState}) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
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
              home: const SubscriptionsScreen(),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('SubscriptionsScreen UI Tests', () {
    testWidgets('Відображає порожній стан (немає підписок)', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final emptyState = SubscriptionState(
        subscriptions: const [],
        dueSubscriptions: const [],
        ignoredSubIds: const {},
        deletedSubscriptions: const [],
      );

      await tester.pumpWidget(await createTestWidget(subState: emptyState));
      await tester.pumpAndSettle();

      expect(find.text('regular_payments'), findsOneWidget);
      expect(find.text('add_subscription'), findsOneWidget);
      expect(
        find.text('no_subscriptions'),
        findsOneWidget,
      ); // Повідомлення про відсутність
    });

    testWidgets('Відображає підписку в майбутньому (без кнопки Pay)', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final stateWithFuture = SubscriptionState(
        subscriptions: [futureSubscription],
        dueSubscriptions: const [],
        ignoredSubIds: const {},
        deletedSubscriptions: const [],
      );

      await tester.pumpWidget(
        await createTestWidget(subState: stateWithFuture),
      );
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('needs_payment'), findsNothing); // Немає попередження
      expect(find.text('pay'), findsNothing); // Немає кнопки оплати
    });

    testWidgets('Відображає прострочену підписку та дозволяє оплатити', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final stateWithDue = SubscriptionState(
        subscriptions: [dueSubscription],
        dueSubscriptions: [dueSubscription],
        ignoredSubIds: const {},
        deletedSubscriptions: const [],
      );

      await tester.pumpWidget(await createTestWidget(subState: stateWithDue));
      await tester.pumpAndSettle();

      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('needs_payment'), findsOneWidget); // Є попередження

      // Кнопка оплати має бути на екрані
      final payButton = find.text('pay');
      expect(payButton, findsOneWidget);

      // Натискаємо кнопку оплати
      await tester.tap(payButton);
      await tester.pumpAndSettle(); // Чекаємо на появу Snackbar'а

      // Оскільки ми замокали метод confirmSubscriptionPayment і він повертає true,
      // має з'явитись іконка check_circle_outline або сам текст повідомлення.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
