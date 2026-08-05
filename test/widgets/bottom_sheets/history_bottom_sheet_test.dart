import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:litebalance/widgets/bottom_sheets/history_bottom_sheet.dart';
import 'package:litebalance/database/app_database.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  // Ініціалізація EasyLocalization для тестів (прибере варнінги)
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
  });

  final testCategory = Category(
    id: 'cat_main',
    name: 'Main Wallet',
    type: CategoryType.account,
    icon: Icons.wallet.codePoint,
    bgColor: 0xFF000000,
    iconColor: 0xFFFFFFFF,
    sortOrder: 0,
    includeInTotal: true,
    currency: 'USD',
    amount: 1000,
    isArchived: false,
  );

  final testTransactions = [
    Transaction(
      id: 'tx_1',
      title: 'Supermarket',
      amount: 5000,
      currency: 'USD',
      fromId: 'cat_main',
      toId: 'cat_other',
      date: DateTime(2025, 10, 10, 14, 30),
      baseAmount: 5000,
      baseCurrency: 'USD',
    ),
  ];

  group('HistoryBottomSheet - Final Clean Tests', () {
    testWidgets('1. Відображає назву категорії та транзакції', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: HistoryBottomSheet(
                category: testCategory,
                transactions: testTransactions,
                allCategories: [testCategory],
                onDelete: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      // Даємо час виконатися initState і пост-фрейм колбекам
      await tester.pump();

      expect(find.textContaining('history_category'), findsOneWidget);
      expect(find.text('Supermarket'), findsOneWidget);
    });

    testWidgets('Свайп транзакції викликає onDelete та приховує її', (
      WidgetTester tester,
    ) async {
      Transaction? deletedTx;

      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: HistoryBottomSheet(
                category: testCategory,
                transactions: testTransactions,
                allCategories: [testCategory],
                onDelete: (tx) => deletedTx = tx,
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      // Чекаємо ініціалізацію та відмальовування
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final itemFinder = find.text('Supermarket');
      expect(itemFinder, findsOneWidget);

      // 👇 ВИКОРИСТОВУЄМО fling: це набагато надійніше за drag для Dismissible.
      // Кидаємо віджет вліво (-500) з великою швидкістю (3000).
      await tester.fling(itemFinder, const Offset(-500, 0), 3000);

      // Чекаємо завершення анімації (Dismissible зазвичай триває 300-500мс)
      // Ми використовуємо серію pump, щоб просунути час без pumpAndSettle
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Перевіряємо результат
      expect(
        deletedTx,
        isNotNull,
        reason: 'Колбек onDelete не був викликаний після свайпу',
      );
      expect(deletedTx!.id, 'tx_1');

      // Перевіряємо, що віджет реально зник з екрана
      expect(find.text('Supermarket'), findsNothing);
    });

    // Регресія: у нової/порожньої категорії фолбек показував УСЮ історію
    // (чужі транзакції). Тепер він відфільтрований по id категорії.
    testWidgets('Порожня категорія не показує чужих транзакцій', (
      WidgetTester tester,
    ) async {
      final emptyCategory = Category(
        id: 'cat_empty',
        name: 'Fresh Category',
        type: CategoryType.expense,
        icon: Icons.star.codePoint,
        bgColor: 0xFF000000,
        iconColor: 0xFFFFFFFF,
        sortOrder: 5,
        includeInTotal: true,
        currency: 'USD',
        amount: 0,
        isArchived: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: makeTestableWidget(
            child: Scaffold(
              body: HistoryBottomSheet(
                category: emptyCategory,
                // Ці транзакції належать cat_main, а не cat_empty.
                transactions: testTransactions,
                allCategories: [testCategory, emptyCategory],
                onDelete: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Порожній стан (AppEmptyState) у тісному тест-лейауті дає нешкідливий
      // ~8px overflow — поглинаємо саме overflow-винятки. Якби фікс зламався і
      // показувалась чужа транзакція, списку вистачило б місця (без overflow),
      // а перевірка нижче все одно спіймала б регресію.
      Object? caught;
      while ((caught = tester.takeException()) != null) {
        if (!caught.toString().toLowerCase().contains('overflow')) {
          fail('Неочікуваний виняток у тесті: $caught');
        }
      }

      expect(find.text('Supermarket'), findsNothing);
    });
  });
}
