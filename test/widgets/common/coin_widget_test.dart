import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/widgets/common/coin_widget.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  // Створюємо тестову категорію (mock data)
  final testCategory = Category(
    id: 'test_cat_1',
    type: CategoryType.expense,
    name: 'Продукти',
    icon: Icons.shopping_cart.codePoint,
    bgColor: 0xFFE0E0E0,
    iconColor: 0xFF000000,
    amount: 150000, // 1500 UAH
    budget: 500000, // Бюджет 5000
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
  );

  group('CoinWidget Tests', () {
    testWidgets('Повинен коректно рендерити назву категорії та суму', (
      WidgetTester tester,
    ) async {
      // 1. Будуємо віджет
      await tester.pumpWidget(
        makeTestableWidget(child: CoinWidget(category: testCategory)),
      );

      // Зачікаємо, поки відпрацюють всі анімації (Hero, AnimatedSwitcher тощо)
      await tester.pumpAndSettle();

      // 2. Перевіряємо наявність назви
      expect(find.text('Продукти'), findsOneWidget);

      // 3. Перевіряємо наявність іконки
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);

      // 4. Перевіряємо форматування суми (CurrencyFormatter повинен перетворити 1500 на потрібний формат + UAH)
      // Сума 150000 має відформатуватися як '1 500,00'
      expect(find.textContaining('1 500,00'), findsOneWidget);
      expect(
        find.textContaining('₴'),
        findsOneWidget,
      ); // Або 'UAH', залежить від AppCurrency
    });

    testWidgets('Повинен рендеритися без помилок, якщо бюджет null', (
      WidgetTester tester,
    ) async {
      final categoryWithoutBudget = testCategory.copyWith(
        budget: const drift.Value(
          null,
        ), // Використовуємо Value з drift для null
      );

      await tester.pumpWidget(
        makeTestableWidget(child: CoinWidget(category: categoryWithoutBudget)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Продукти'), findsOneWidget);
      // Якщо бюджет null, CircularProgressIndicator не повинен відображатись
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
