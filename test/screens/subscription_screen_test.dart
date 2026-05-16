import 'dart:async';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/subscription_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

// ==========================================
// 1. ЗАГЛУШКА ЛОКАЛІЗАЦІЇ
// ==========================================
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{
      'new_subscription': 'New Sub',
      'edit': 'Edit',
      'name_hint_netflix': 'Name',
      'amount': 'Amount',
      'currency': 'Currency',
      'payment': 'Payment Date',
      'period': 'Period',
      'period_monthly': 'Monthly',
      'period_yearly': 'Yearly',
      'period_weekly': 'Weekly',
      'write_off_from': 'Account',
      'expense_category': 'Category',
      'auto_pay': 'Auto Pay',
      'choose_icon': 'Choose Icon',
      'use_category_icon': 'Use default',
      'delete_subscription_title': 'Delete?',
      'delete_subscription_message': 'Delete {}?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'base_currency_label': 'Base',
      'icons_finance': 'Finance',
      'icons_currencies': 'Currencies',
      'icons_food': 'Food',
      'icons_transport': 'Transport',
      'icons_home': 'Home',
      'icons_shopping': 'Shopping',
      'icons_health': 'Health',
      'icons_entertainment': 'Entertainment',
      'icons_subscriptions': 'Subscriptions',
      'icons_family': 'Family',
      'icons_other': 'Other',
      'choose_date': 'Choose Date',
      'date': 'Date',
      'update_date': 'Update',
    };
  }
}

// ==========================================
// 2. МОК-НОТИФІКАТОРИ
// ==========================================

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
    selectedCurrencies: const ['UAH', 'USD', 'EUR'],
    exchangeRates: const {},
    historicalCache: const {},
  );
}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  final SubscriptionState mockState;
  bool addCalled = false;
  bool updateCalled = false;
  bool trashCalled = false;

  TestSubscriptionNotifier(this.mockState);

  @override
  Future<SubscriptionState> build() async => mockState;

  @override
  Future<void> addSubscription(Subscription sub) async {
    addCalled = true;
  }

  @override
  Future<void> updateSubscription(Subscription sub) async {
    updateCalled = true;
  }

  @override
  Future<void> moveToTrash(Subscription sub) async {
    trashCalled = true;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void setHugeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
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
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
  );

  const dummyExpense = Category(
    id: 'exp_1',
    type: CategoryType.expense,
    name: 'Subscriptions',
    icon: 0xe041,
    bgColor: 0xFFF44336,
    iconColor: 0xFFFFFFFF,
    amount: 0,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 1,
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
  );

  final defaultCategoryState = CategoryState(
    incomes: const [],
    accounts: const [dummyAccount],
    expenses: const [dummyExpense],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  final defaultSubscriptionState = SubscriptionState(
    subscriptions: [dummySubscription],
    dueSubscriptions: const [],
    ignoredSubIds: const {},
    deletedSubscriptions: const [],
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestApp({TestSubscriptionNotifier? subNotifier}) async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        subscriptionProvider.overrideWith(
          () =>
              subNotifier ?? TestSubscriptionNotifier(defaultSubscriptionState),
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
              localizationsDelegates: context.localizationDelegates,
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
              // 👇 ДОДАНО: Головний екран-пустишка, щоб Navigator.pop() не ламав тест
              home: const Scaffold(body: Center(child: Text('ROOT_SCREEN'))),
            );
          },
        ),
      ),
    );
  }

  // Хелпер для зручного відкриття нашого екрана поверх Root
  Future<void> openSubscriptionScreen(
    WidgetTester tester, {
    Subscription? subscription,
    TestSubscriptionNotifier? subNotifier,
  }) async {
    await tester.pumpWidget(await createTestApp(subNotifier: subNotifier));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('ROOT_SCREEN'));
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(subscription: subscription),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ==========================================
  // ТЕСТИ
  // ==========================================
  group('SubscriptionScreen Coverage Tests', () {
    testWidgets('1. Валідація: Порожня форма не зберігається', (tester) async {
      setHugeScreen(tester);
      final subNotifier = TestSubscriptionNotifier(defaultSubscriptionState);

      await openSubscriptionScreen(tester, subNotifier: subNotifier);

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(subNotifier.addCalled, false);
    });

    testWidgets('2. Успішне створення нової підписки', (tester) async {
      setHugeScreen(tester);
      final subNotifier = TestSubscriptionNotifier(defaultSubscriptionState);

      await openSubscriptionScreen(tester, subNotifier: subNotifier);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Gym');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '005.5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle(); // Тепер pop спрацює без крашу!

      expect(subNotifier.addCalled, true);
    });

    testWidgets('3. Редагування: Збереження та видалення існуючої підписки', (
      tester,
    ) async {
      setHugeScreen(tester);
      final subNotifier = TestSubscriptionNotifier(defaultSubscriptionState);

      // Перевіряємо збереження (update)
      await openSubscriptionScreen(
        tester,
        subscription: dummySubscription,
        subNotifier: subNotifier,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Netflix Premium',
      );
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(subNotifier.updateCalled, true);

      // Перевіряємо видалення (delete)
      await openSubscriptionScreen(
        tester,
        subscription: dummySubscription,
        subNotifier: subNotifier,
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(subNotifier.trashCalled, true);
    });

    testWidgets('4. Робота Picker-ів (Періодичність, Валюта, Іконка, Дата)', (
      tester,
    ) async {
      setHugeScreen(tester);
      await openSubscriptionScreen(tester, subscription: dummySubscription);

      // ПЕРІОДИЧНІСТЬ
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(find.text('Yearly'), findsOneWidget);

      // ВАЛЮТА
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();

      // ІКОНКА
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default'));
      await tester.pumpAndSettle();

      // ДАТА (Відкриття та збереження)
      final dateField = find
          .ancestor(
            of: find.text('Payment Date'),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(dateField);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
    });

    testWidgets('5. Перевірка логіки InputFormatter для сум', (tester) async {
      setHugeScreen(tester);
      await openSubscriptionScreen(tester);

      final amountField = find.widgetWithText(TextField, 'Amount');

      await tester.enterText(amountField, '.5');
      await tester.pumpAndSettle();
      expect(find.text('0.5'), findsOneWidget);

      await tester.enterText(amountField, '1000000');
      await tester.pumpAndSettle();
      expect(find.text('1 000 000'), findsOneWidget);

      await tester.enterText(amountField, '000007.89');
      await tester.pumpAndSettle();
      expect(find.text('7.89'), findsOneWidget);
    });
  });
}
