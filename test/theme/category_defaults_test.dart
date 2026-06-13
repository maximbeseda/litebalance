import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/theme/category_defaults.dart';
import 'package:litebalance/database/app_database.dart';

void main() {
  group('CategoryDefaults Tests', () {
    test('1. Перевірка статичних констант', () {
      expect(CategoryDefaults.incomeBg, Colors.black);
      expect(CategoryDefaults.accountBg, const Color(0xFF1E3A5F));
      expect(CategoryDefaults.expenseBg, const Color(0xFFE0DFE8));
    });

    test('2. getBgColor повертає правильні кольори для кожного типу', () {
      expect(
        CategoryDefaults.getBgColor(CategoryType.income),
        CategoryDefaults.incomeBg,
      );
      expect(
        CategoryDefaults.getBgColor(CategoryType.account),
        CategoryDefaults.accountBg,
      );
      expect(
        CategoryDefaults.getBgColor(CategoryType.expense),
        CategoryDefaults.expenseBg,
      );
    });

    test('3. getIconColor повертає чорний для витрат та білий для інших', () {
      // Витрати - чорна іконка
      expect(CategoryDefaults.getIconColor(CategoryType.expense), Colors.black);

      // Доходи - біла іконка
      expect(CategoryDefaults.getIconColor(CategoryType.income), Colors.white);

      // Рахунки - біла іконка
      expect(CategoryDefaults.getIconColor(CategoryType.account), Colors.white);
    });
  });
}
