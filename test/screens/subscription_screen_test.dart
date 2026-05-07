import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/subscription_screen.dart';
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

// 👇 ВИПРАВЛЕНО: Оновлені параметри SettingsState згідно з помилками компілятора
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

  @override
  Future<void> addSubscription(Subscription sub) async {}

  @override
  Future<void> updateSubscription(Subscription sub) async {}

  @override
  Future<void> moveToTrash(Subscription sub) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void setHugeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 3000);
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

  final dummySubscription = Subscription(
    id: 'sub_1',
    name: 'Netflix',
    amount: 1500, // 15.00
    categoryId: 'exp_1',
    accountId: 'acc_1',
    nextPaymentDate: DateTime(2026, 5, 20),
    periodicity: 'monthly',
    customIconCodePoint: null,
    isAutoPay: true,
    currency: 'USD',
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

  // 👇 ВИПРАВЛЕНО: Оновлені параметри SubscriptionState згідно з помилками компілятора
  final defaultSubscriptionState = SubscriptionState(
    subscriptions: [dummySubscription],
    dueSubscriptions: [],
    ignoredSubIds: {},
    deletedSubscriptions: const [],
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget({Subscription? subscription}) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(defaultSubscriptionState),
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
              home: SubscriptionScreen(subscription: subscription),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('SubscriptionScreen UI Tests', () {
    testWidgets('Відображає екран СТВОРЕННЯ нової підписки', (tester) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget(subscription: null));
      await tester.pumpAndSettle();

      expect(find.text('new_subscription'), findsOneWidget);
      expect(find.text('name_hint_netflix'), findsOneWidget);
      expect(find.text('amount'), findsOneWidget);
      expect(find.text('currency'), findsOneWidget);
      expect(find.text('payment'), findsOneWidget);
      expect(find.text('period'), findsOneWidget);
      expect(find.text('write_off_from'), findsOneWidget);
      expect(find.text('expense_category'), findsOneWidget);
      expect(find.text('auto_pay'), findsOneWidget);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Відображає екран РЕДАГУВАННЯ існуючої підписки', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(subscription: dummySubscription),
      );
      await tester.pumpAndSettle();

      expect(find.text('edit'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('USD'), findsWidgets);

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('Відкриває BottomSheet для вибору періодичності', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget(subscription: null));
      await tester.pumpAndSettle();

      final periodField = find
          .ancestor(
            of: find.text('period'),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(periodField);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'period_monthly'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'period_yearly'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'period_weekly'), findsOneWidget);
    });

    testWidgets('Відкриває діалог видалення при натисканні на кошик', (
      tester,
    ) async {
      setHugeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        await createTestWidget(subscription: dummySubscription),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('delete_subscription_title'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
      expect(find.text('delete'), findsOneWidget);
    });
  });
}
