import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/bottom_sheets/general_history_bottom_sheet.dart'; // Перевірте шлях!
import 'package:litebalance/database/app_database.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
  });

  // Тестові дані
  final testAccCat = Category(
    id: 'acc_1',
    name: 'Card',
    type: CategoryType.account,
    icon: Icons.credit_card.codePoint,
    bgColor: 0xFF000000,
    iconColor: 0xFFFFFFFF,
    sortOrder: 0,
    includeInTotal: true,
    currency: 'USD',
    amount: 1000,
    isArchived: false,
  );

  final testExpCat = Category(
    id: 'exp_1',
    name: 'Food',
    type: CategoryType.expense,
    icon: Icons.fastfood.codePoint,
    bgColor: 0xFF000000,
    iconColor: 0xFFFFFFFF,
    sortOrder: 1,
    includeInTotal: true,
    currency: 'USD',
    amount: 0,
    isArchived: false,
  );

  final testTransactions = [
    Transaction(
      id: 'tx_gen_1',
      title: 'Lunch',
      amount: 1500, // 15.00
      currency: 'USD',
      fromId: 'acc_1',
      toId: 'exp_1',
      date: DateTime(2025, 12, 01, 12, 00),
      baseAmount: 1500,
      baseCurrency: 'USD',
    ),
  ];

  group('GeneralHistoryBottomSheet Tests', () {
    testWidgets('1. Відображає заголовок та транзакції', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: GeneralHistoryBottomSheet(
                title: 'Test History',
                filterType: CategoryType.expense,
                transactions: testTransactions,
                allCategories: [testAccCat, testExpCat],
                onDelete: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Test History'), findsOneWidget);
      // Шукаємо за сумою, яка точно є в testTransactions
      expect(find.textContaining('15'), findsWidgets);
    });

    testWidgets('2. Свайп транзакції викликає onDelete', (
      WidgetTester tester,
    ) async {
      Transaction? deletedTx;

      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: GeneralHistoryBottomSheet(
                title: 'Test',
                filterType: CategoryType.expense,
                transactions: testTransactions,
                allCategories: [testAccCat, testExpCat],
                onDelete: (tx) => deletedTx = tx,
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Даємо час на ініціалізацію провайдерів у фоні
      await tester.pump(const Duration(milliseconds: 100));

      // Знаходимо айтем (через суму або назву)
      final itemFinder = find.textContaining('15').first;

      // 👇 ВИКОРИСТОВУЄМО fling: це набагато надійніше для Dismissible
      await tester.fling(itemFinder, const Offset(-500, 0), 3000);

      // 👇 КРИТИЧНО: замість pumpAndSettle, робимо цикл pump,
      // щоб завершити анімацію видалення, не чекаючи лоадерів
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(deletedTx, isNotNull, reason: 'Колбек onDelete не був викликаний');
      expect(deletedTx!.id, 'tx_gen_1');
      expect(find.textContaining('15'), findsNothing);
    });
  });
  group('GeneralHistoryBottomSheet Tests', () {
    testWidgets('1. Відображає заголовок та транзакції', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: GeneralHistoryBottomSheet(
                title: 'Test History',
                filterType: CategoryType.expense,
                transactions: testTransactions,
                allCategories: [testAccCat, testExpCat],
                onDelete: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Test History'), findsOneWidget);
      // Шукаємо за сумою, яка точно є в testTransactions
      expect(find.textContaining('15'), findsWidgets);
    });

    testWidgets('2. Свайп транзакції викликає onDelete', (
      WidgetTester tester,
    ) async {
      Transaction? deletedTx;

      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: GeneralHistoryBottomSheet(
                title: 'Test',
                filterType: CategoryType.expense,
                transactions: testTransactions,
                allCategories: [testAccCat, testExpCat],
                onDelete: (tx) => deletedTx = tx,
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Даємо час на ініціалізацію провайдерів у фоні
      await tester.pump(const Duration(milliseconds: 100));

      // Знаходимо айтем (через суму або назву)
      final itemFinder = find.textContaining('15').first;

      // 👇 ВИКОРИСТОВУЄМО fling: це набагато надійніше для Dismissible
      await tester.fling(itemFinder, const Offset(-500, 0), 3000);

      // 👇 КРИТИЧНО: замість pumpAndSettle, робимо цикл pump,
      // щоб завершити анімацію видалення, не чекаючи лоадерів
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(deletedTx, isNotNull, reason: 'Колбек onDelete не був викликаний');
      expect(deletedTx!.id, 'tx_gen_1');
      expect(find.textContaining('15'), findsNothing);
    });
  });
}
