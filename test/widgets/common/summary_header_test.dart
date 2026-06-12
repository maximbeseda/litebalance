import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/providers/settings_provider.dart';
import 'package:litebalance/providers/subscription_provider.dart';
import 'package:litebalance/widgets/common/summary_header.dart';
import 'package:litebalance/widgets/common/animated_dots.dart';
import 'package:litebalance/widgets/common/rolling_digit.dart';

import '../../helpers/test_wrapper.dart';

// ==========================================
// 1. МОКИ ДЛЯ RIVERPOD
// ==========================================

// Фейковий провайдер налаштувань
class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      baseCurrency: 'USD', // Тестуємо з доларом
      selectedCurrencies: ['USD'],
      exchangeRates: {},
      historicalCache: {},
    );
  }
}

// Фейковий провайдер підписок
class MockSubscriptionNotifier extends SubscriptionNotifier {
  final bool hasPending;

  MockSubscriptionNotifier(this.hasPending);

  @override
  Future<SubscriptionState> build() async {
    return SubscriptionState(
      // Якщо hasPending = true, симулюємо прострочену підписку (вчорашня дата)
      subscriptions: hasPending
          ? [
              Subscription(
                id: '1',
                name: 'Test Sub',
                amount: 100,
                categoryId: 'c1',
                accountId: 'a1',
                nextPaymentDate: DateTime.now().subtract(
                  const Duration(days: 1),
                ),
                periodicity: 'monthly',
                isAutoPay: false,
                currency: 'USD',
              ),
            ]
          : [],
      dueSubscriptions: [],
      deletedSubscriptions: [],
      ignoredSubIds: {},
    );
  }
}

// ==========================================
// 2. ТЕСТИ
// ==========================================

void main() {
  group('SummaryHeader Tests', () {
    testWidgets('Рендерить суми, валюту USD та обробляє натискання', (
      WidgetTester tester,
    ) async {
      bool balanceTapped = false;
      bool incomesTapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          // 👇 МАГІЯ: Підміняємо реальні провайдери на наші фейкові
          overrides: [
            settingsProvider.overrideWith(() => MockSettingsNotifier()),
            subscriptionProvider.overrideWith(
              () => MockSubscriptionNotifier(false),
            ),
          ],
          child: SummaryHeader(
            totalBalance: 1500000, // 15 000.00
            totalIncomes: 200000, // 2 000.00
            totalExpenses: 50000, // 500.00
            onBalanceTap: () => balanceTapped = true,
            onIncomesTap: () => incomesTapped = true,
            onExpensesTap: () {},
            onSettingsTap: () {},
          ),
        ),
      );

      // Чекаємо завершення анімацій та асинхронних Future
      await tester.pumpAndSettle();

      // 1. Перевіряємо, що суми розбилися на символи і відрендерились через RollingDigit
      expect(find.byType(RollingDigit), findsWidgets);

      // 2. Оскільки ми замокали baseCurrency на 'USD', перевіряємо символ '$'.
      // У вашому коді він рендериться як окремий Text(' $currencySymbol'), тому шукаємо ' $'
      expect(find.text(' \$'), findsWidgets);

      // 3. Перевіряємо кліки по іконках
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.tap(find.byIcon(Icons.north_east));

      expect(balanceTapped, true);
      expect(incomesTapped, true);

      // Перевіряємо відсутність червоної крапки повідомлення (бо hasPending = false)
      final badgeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(badgeFinder, findsNothing);
    });

    testWidgets(
      'Показує червону крапку (badge) та AnimatedDots під час міграції',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            overrides: [
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
              // 👇 Тепер кажемо, що є неоплачені підписки!
              subscriptionProvider.overrideWith(
                () => MockSubscriptionNotifier(true),
              ),
            ],
            child: SummaryHeader(
              totalBalance: 0,
              totalIncomes: 0,
              totalExpenses: 0,
              isMigrating: true, // Симулюємо процес міграції бази
              onBalanceTap: () {},
              onIncomesTap: () {},
              onExpensesTap: () {},
              onSettingsTap: () {},
            ),
          ),
        );

        await tester
            .pump(); // Використовуємо pump замість pumpAndSettle, бо AnimatedDots — це нескінченна анімація

        // 1. Перевіряємо, чи з'явилася червона крапка
        final badgeFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(badgeFinder, findsOneWidget);

        // 2. Перевіряємо, чи відображається AnimatedDots замість звичайних цифр
        expect(find.byType(AnimatedDots), findsWidgets);
      },
    );
  });
}
