import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/bottom_sheets/stats_category_bottom_sheet.dart';
import 'package:litebalance/database/app_database.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    // 1. Імітуємо сховище
    SharedPreferences.setMockInitialValues({});
    // 2. 👇 ДОДАНО: Ініціалізуємо дані форматів дат для тестів
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('uk', null);
  });

  final testCategory = Category(
    id: 'cat_test',
    name: 'Food & Drinks',
    type: CategoryType.expense,
    icon: Icons.fastfood.codePoint,
    bgColor: 0xFFFF0000,
    iconColor: 0xFFFFFFFF,
    sortOrder: 0,
    includeInTotal: true,
    currency: 'USD',
    amount: 15000, // 150.00
    isArchived: false,
  );

  final testTransactions = [
    Transaction(
      id: 'tx_stats_1',
      title: 'Burger King',
      amount: 2500, // 25.00
      currency: 'USD',
      fromId: 'acc_wallet',
      toId: 'cat_test',
      date: DateTime(2026, 04, 15, 13, 00),
      baseAmount: 2500,
      baseCurrency: 'USD',
    ),
  ];

  Future<void> pumpStatsSheet(
    WidgetTester tester, {
    required List<Transaction> transactions,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: makeTestableWidget(
          child: Scaffold(
            body: StatsCategoryBottomSheet(
              category: testCategory,
              statsMonth: DateTime(2026, 04),
              baseCurrencySymbol: '\$',
              showExpenses: true,
              initialTransactions: transactions,
            ),
          ),
        ),
      ),
    );

    // 👇 КРИТИЧНО: використовуємо pump(Duration), щоб пропустити анімації,
    // але не чекати "заспокоєння" всіх індикаторів.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('StatsCategoryBottomSheet Tests', () {
    testWidgets('1. Відображає назву категорії та загальну суму за місяць', (
      WidgetTester tester,
    ) async {
      await pumpStatsSheet(tester, transactions: []);

      expect(find.text('Food & Drinks'), findsOneWidget);
      // Перевіряємо суму категорії (150.00)
      expect(find.textContaining('150'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Показує список транзакцій цієї категорії', (
      WidgetTester tester,
    ) async {
      await pumpStatsSheet(tester, transactions: testTransactions);

      // Маємо побачити назву транзакції
      expect(find.text('Burger King'), findsOneWidget);
      // І її суму (25.00)
      expect(find.textContaining('25'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Показує повідомлення, якщо транзакцій немає', (
      WidgetTester tester,
    ) async {
      await pumpStatsSheet(tester, transactions: []);

      // Порожній список -> уніфікований порожній стан із заголовком
      expect(find.text('no_transactions_yet'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
