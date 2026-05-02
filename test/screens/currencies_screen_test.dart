import 'package:coin_flow/models/app_currency.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/currencies_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ======================================================================
// 1. СТВОРЕННЯ FAKE-НОТИФІКАТОРА ДЛЯ ПЕРЕХОПЛЕННЯ ДІЙ
// ======================================================================
class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState mockState;

  bool forceUpdateRatesCalled = false;
  String? toggledCurrencyCode;
  bool updateSuccess = true;

  FakeSettingsNotifier(this.mockState);

  @override
  SettingsState build() => mockState;

  @override
  Future<bool> forceUpdateRates() async {
    forceUpdateRatesCalled = true;
    // 👇 ДОДАНО ЗА ЗАТРИМКУ: Щоб UI встиг намалювати CircularProgressIndicator
    await Future.delayed(const Duration(milliseconds: 100));
    return updateSuccess;
  }

  @override
  Future<void> toggleSelectedCurrency(String code) async {
    toggledCurrencyCode = code;
  }
}

void main() {
  late SettingsState defaultState;
  late FakeSettingsNotifier fakeNotifier;

  setUp(() {
    defaultState = SettingsState(
      baseCurrency: 'USD',
      selectedCurrencies: ['USD', 'EUR'],
      exchangeRates: {'USD': 1.0, 'EUR': 0.9, 'UAH': 40.0},
      lastRatesUpdate: DateTime(2026, 1, 1, 12, 0),
      historicalCache: {},
    );
    fakeNotifier = FakeSettingsNotifier(defaultState);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [settingsProvider.overrideWith(() => fakeNotifier)],
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
        home: const CurrenciesScreen(),
      ),
    );
  }

  group('CurrenciesScreen Widget Tests', () {
    testWidgets('Правильно відображає базову валюту та інші вибрані валюти', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(
        find.byIcon(Icons.delete_outline),
        findsOneWidget,
      ); // Тільки 1 кнопка (для EUR)
      expect(find.text('base_currency'), findsOneWidget);
    });

    testWidgets(
      'Викликає forceUpdateRates при натисканні на іконку оновлення',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Натискаємо іконку рефрешу
        await tester.tap(find.byIcon(Icons.refresh));

        // Рендеримо кадр одразу після натискання (зараз _isUpdating = true)
        await tester.pump();

        // Перевіряємо, що лоадер з'явився
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text('updating_rates'), findsOneWidget);

        // Дочікуємось кінця 100-мілісекундної затримки та анімацій
        await tester.pumpAndSettle();

        expect(fakeNotifier.forceUpdateRatesCalled, isTrue);
      },
    );

    testWidgets('Показує помилку, якщо оновлення курсів не вдалося', (
      tester,
    ) async {
      fakeNotifier.updateSuccess = false;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle(); // Дочікуємось завершення завантаження

      // Перевіряємо, що з'явився текст помилки
      expect(find.text('rates_update_error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // 👇 ВИПРАВЛЕНО: Перемотуємо час на 3 секунди, щоб таймер зникнення помилки відпрацював!
      // Якщо цього не зробити, Flutter викине "Timer is still pending"
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Викликає toggleSelectedCurrency при видаленні валюти', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(fakeNotifier.toggledCurrencyCode, 'EUR');
    });

    testWidgets(
      'Відкриває BottomSheet і додає нову валюту при натисканні FAB',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('add_currency'), findsOneWidget);

        await tester.dragUntilVisible(
          find.text('UAH'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('UAH'));
        await tester.pumpAndSettle();

        expect(fakeNotifier.toggledCurrencyCode, 'UAH');
      },
    );

    testWidgets(
      'Показує "all_currencies_added", якщо більше немає що додавати',
      (tester) async {
        final allCodes = AppCurrency.supportedCurrencies
            .map((c) => c.code)
            .toList();
        final fullState = SettingsState(
          baseCurrency: 'USD',
          selectedCurrencies: allCodes,
          exchangeRates: {},
          historicalCache: {},
        );
        final fullNotifier = FakeSettingsNotifier(fullState);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsProvider.overrideWith(() => fullNotifier)],
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
              supportedLocales: const [Locale('en')],
              locale: const Locale('en'),
              home: const CurrenciesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('all_currencies_added'), findsOneWidget);
      },
    );
  });
}
