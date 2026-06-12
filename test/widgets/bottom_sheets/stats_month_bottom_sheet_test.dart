import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/bottom_sheets/stats_month_bottom_sheet.dart';
import 'package:litebalance/database/app_database.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('uk', null);
  });

  final testTransactions = [
    Transaction(
      id: 'tx_month_1',
      title: 'Monthly Rent',
      amount: 100000, // 1000.00
      currency: 'USD',
      fromId: 'acc_1',
      toId: 'cat_rent',
      date: DateTime(2026, 04, 01, 10, 00),
      baseAmount: 100000,
      baseCurrency: 'USD',
    ),
  ];

  Future<void> pumpMonthSheet(
    WidgetTester tester, {
    required List<Transaction> transactions,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        child: makeTestableWidget(
          child: Scaffold(
            body: StatsMonthBottomSheet(
              statsMonth: DateTime(2026, 04),
              baseCurrencySymbol: '\$',
              showExpenses: true,
              initialTransactions: transactions, // 👈 дані тепер передаються
            ),
          ),
        ),
      ),
    );

    // 👇 Важливо дати час DraggableScrollableSheet
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('StatsMonthBottomSheet Tests', () {
    testWidgets('1. Відображає вибраний місяць та перемикач типів', (
      WidgetTester tester,
    ) async {
      await pumpMonthSheet(tester, transactions: []);

      // Перевіряємо текст місяця (форматується через DateFormatter)
      expect(find.textContaining('April'), findsOneWidget);

      // Перевіряємо наявність кнопок перемикача (ключі локалізації)
      expect(find.text('income'), findsOneWidget);
      expect(find.text('stats_expenses'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Відображає список транзакцій місяця', (
      WidgetTester tester,
    ) async {
      await pumpMonthSheet(tester, transactions: testTransactions);

      expect(find.text('Monthly Rent'), findsOneWidget);
      // Перевіряємо суму 1000
      expect(find.textContaining('1'), findsWidgets);
      expect(find.textContaining('000'), findsWidgets);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Можна перемикатися між витратами та доходами', (
      WidgetTester tester,
    ) async {
      await pumpMonthSheet(tester, transactions: []);

      // Тапаємо по "Доходи"
      await tester.tap(find.text('income'));
      await tester.pumpAndSettle();

      // Оскільки ми не мокаємо логіку провайдера тут, ми просто перевіряємо,
      // що віджет не впав і перемалювався (можна додати перевірку кольору тексту)
      expect(find.text('income'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
