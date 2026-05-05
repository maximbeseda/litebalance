import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:coin_flow/widgets/dialogs/due_subscription_dialog.dart';
import 'package:coin_flow/providers/all_providers.dart';
import '../../helpers/test_wrapper.dart';

// --- МОКИ ТА ФЕЙКИ ---

class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      baseCurrency: 'USD',
      selectedCurrencies: ['USD', 'UAH'],
      exchangeRates: {'USD': 1.0, 'UAH': 40.0},
      historicalCache: {},
      lastRatesUpdate: DateTime.now(),
    );
  }
}

class MockSubscriptionNotifier extends SubscriptionNotifier {
  bool skipCalled = false;
  bool ignoreCalled = false;

  @override
  Future<void> skipSubscriptionPayment(Subscription sub) async {
    skipCalled = true;
  }

  @override
  Future<void> ignoreSubscriptionForSession(String id) async {
    ignoreCalled = true;
  }
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('uk', null);
    await initializeDateFormatting('en', null);
  });

  final testSubscription = Subscription(
    id: 'test_sub_1',
    name: 'Netflix Premium',
    amount: 1500, // 15.00
    currency: 'USD',
    accountId: 'acc_1',
    categoryId: 'cat_1',
    nextPaymentDate: DateTime(2026, 5, 10),
    periodicity: 'monthly',
    isAutoPay: false,
  );

  Future<void> pumpDialogApp(
    WidgetTester tester,
    SharedPreferences prefs,
    MockSubscriptionNotifier subNotifier,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(() => TestSettingsNotifier()),
          subscriptionProvider.overrideWith(() => subNotifier),
        ],
        // 👇 Використовуємо ваш стандартний враппер замість ручного EasyLocalization
        child: makeTestableWidget(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) =>
                          DueSubscriptionDialog(subscription: testSubscription),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('DueSubscriptionDialog Tests', () {
    late SharedPreferences prefs;
    late MockSubscriptionNotifier mockSubNotifier;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      mockSubNotifier = MockSubscriptionNotifier();
    });

    testWidgets('1. Відображає правильні дані підписки (Назва, Сума)', (
      WidgetTester tester,
    ) async {
      await pumpDialogApp(tester, prefs, mockSubNotifier);

      // 👇 ВИПРАВЛЕНО: Додано findRichText: true для пошуку всередині TextSpan
      expect(
        find.textContaining('Netflix Premium', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('15', findRichText: true), findsOneWidget);
      expect(find.textContaining('\$', findRichText: true), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Стан "Недостатньо коштів" (canPay = false)', (
      WidgetTester tester,
    ) async {
      await pumpDialogApp(tester, prefs, mockSubNotifier);

      expect(find.byIcon(Icons.money_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      '3. Натискання "Пропустити" (Skip) закриває діалог і викликає метод',
      (WidgetTester tester) async {
        await pumpDialogApp(tester, prefs, mockSubNotifier);

        final skipBtn = find.byType(TextButton);
        expect(skipBtn, findsOneWidget);

        await tester.tap(skipBtn);
        await tester.pumpAndSettle();

        expect(find.byType(DueSubscriptionDialog), findsNothing);
        expect(mockSubNotifier.skipCalled, isTrue);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets('4. Натискання на хрестик закриває діалог і викликає ignore', (
      WidgetTester tester,
    ) async {
      await pumpDialogApp(tester, prefs, mockSubNotifier);

      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DueSubscriptionDialog), findsNothing);
      expect(mockSubNotifier.ignoreCalled, isTrue);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
