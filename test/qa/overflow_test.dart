// Overflow stress test for the home screen across all supported locales.
//
// Renders the home screen at a narrow phone width with worst-case content
// (very long category names + large amounts) in every supported locale and
// asserts that no `RenderFlex`/layout overflow exception is thrown.
//
// Rationale: overflow is a layout-time error in Flutter; if any row/column on
// the home screen lacks a Flexible/Expanded/ellipsis guard, laying it out with
// long localized strings throws "A RenderFlex overflowed", which fails the test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/screens/home_screen.dart';
import 'package:litebalance/theme/app_theme.dart';

// All locales the app ships (mirrors lib/main.dart).
const supported = <Locale>[
  Locale('uk'), Locale('en'), Locale('de'), Locale('pl'), Locale('es'),
  Locale('fr'), Locale('it'), Locale('pt'), Locale('nl'), Locale('tr'),
  Locale('cs'), Locale('ro'), Locale('hu'), Locale('sk'), Locale('el'),
  Locale('bg'), Locale('sv'), Locale('da'), Locale('fi'), Locale('hr'),
];

// Worst-case long names to stress the category coin layout (longer than any
// real localized default category name).
Category _cat(String id, CategoryType type, String name, int amount) => Category(
  id: id,
  name: name,
  type: type,
  currency: 'USD',
  amount: amount,
  icon: 0xe57f, // a valid material codepoint
  bgColor: 0xFF000000,
  iconColor: 0xFFFFFFFF,
  isArchived: false,
  includeInTotal: true,
  sortOrder: 0,
);

final _longState = CategoryState(
  incomes: [
    _cat('i1', CategoryType.income, 'Gehaltszahlung Hauptkonto Februar', 1234567),
    _cat('i2', CategoryType.income, 'Nebeneinkünfte und Honorare', 987654),
  ],
  accounts: [
    _cat('a1', CategoryType.account, 'Sparkonto Festgeldreserve langfristig', 99999999),
    _cat('a2', CategoryType.account, 'Kreditkarte Hauptkonto', 4567890),
  ],
  expenses: [
    _cat('e1', CategoryType.expense, 'Lebensmittel und Haushaltswaren', 321456),
    _cat('e2', CategoryType.expense, 'Öffentliche Verkehrsmittel Monatskarte', 87654),
    _cat('e3', CategoryType.expense, 'Unterhaltung und Freizeitaktivitäten', 45678),
    _cat('e4', CategoryType.expense, 'Gesundheit und Medikamente Apotheke', 234567),
  ],
  archivedCategories: const [],
  deletedCategories: const [],
  isLoading: false,
);

class _SpyCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => _longState;
  @override
  Future<void> addOrUpdateCategory(Category cat) async {}
  @override
  Future<void> moveToTrash(Category cat) async {}
}

class _SpyTransactionNotifier extends TransactionNotifier {
  @override
  Future<TransactionState> build() async => TransactionState(
    history: const [],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
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

class _BigStats extends Stats {
  @override
  void build() {}
  @override
  Map<String, int> calculateTotalsForMonth(DateTime month) => const {
    'incomes': 999999999,
    'expenses': 888888888,
  };
  @override
  Map<String, int> calculateCategoryTotalsForMonth(
    DateTime m,
    bool iE, {
    bool inBaseCurrency = true,
  }) => const {};
}

Widget _app(Locale locale, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      categoryProvider.overrideWith(_SpyCategoryNotifier.new),
      transactionProvider.overrideWith(_SpyTransactionNotifier.new),
      subscriptionProvider.overrideWith(SubscriptionNotifier.new),
      settingsProvider.overrideWith(_TestSettingsNotifier.new),
      statsProvider.overrideWith(_BigStats.new),
      homeScreenControllerProvider.overrideWith(HomeScreenController.new),
    ],
    child: EasyLocalization(
      supportedLocales: supported,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.getTheme('light'),
          home: const HomeScreen(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final locale in supported) {
    testWidgets('home screen has no overflow in "${locale.languageCode}" '
        '(narrow width, long content)', (tester) async {
      // Narrow phone width — the tightest realistic layout.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_app(locale, prefs));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.takeException(),
        isNull,
        reason: 'Overflow/layout error on home screen for locale '
            '${locale.languageCode}',
      );
    });
  }

  // Memory: mount the home screen, then unmount it, and let leak_tracker verify
  // that every disposable (controllers, timers, listeners, etc.) was released
  // and garbage-collected. A leaked object fails the test with details.
  testWidgets(
    'home screen releases all resources on dispose (no leaks)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_app(const Locale('en'), prefs));
      await tester.pump(const Duration(milliseconds: 300));

      // Tear the whole tree down so disposables run their dispose().
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
    experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
  );
}
