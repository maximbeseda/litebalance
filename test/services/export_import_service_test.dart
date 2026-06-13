import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/services/export_import_service.dart';

void main() {
  group('ExportImportService - CSV Generation', () {
    const uahAcc = Category(
      id: 'acc_1',
      name: 'Card',
      type: CategoryType.account,
      currency: 'UAH',
      amount: 0,
      icon: 0,
      bgColor: 0,
      iconColor: 0,
      isArchived: false,
      includeInTotal: true,
      sortOrder: 0,
    );
    const foodExp = Category(
      id: 'exp_1',
      name: 'Food, Drinks',
      type: CategoryType.expense,
      currency: 'UAH',
      amount: 0,
      icon: 0,
      bgColor: 0,
      iconColor: 0,
      isArchived: false,
      includeInTotal: true,
      sortOrder: 1,
    );

    test('Повинен правильно екранувати коми в назвах категорій', () {
      final tx = Transaction(
        id: '1',
        fromId: 'acc_1',
        toId: 'exp_1',
        title: '',
        amount: 10000,
        date: DateTime(2026, 1, 1),
        currency: 'UAH',
        baseAmount: 10000,
        baseCurrency: 'UAH',
      );

      final csv = ExportImportService.generateCsvString(
        transactions: [tx],
        allCategories: [uahAcc, foodExp],
      );

      // Оскільки "Food, Drinks" має кому, вона повинна бути в лапках: "Food, Drinks"
      expect(csv.contains('"Food, Drinks"'), true);
    });

    test('Повинен очищувати системні коментарі', () {
      final txWithArrow = Transaction(
        id: '2',
        fromId: 'acc_1',
        toId: 'exp_1',
        title: 'Card ➡️ Food, Drinks',
        amount: 5000,
        date: DateTime(2026, 1, 1),
        currency: 'UAH',
        baseAmount: 5000,
        baseCurrency: 'UAH',
      );

      final csv = ExportImportService.generateCsvString(
        transactions: [txWithArrow],
        allCategories: [uahAcc, foodExp],
      );

      // Остання колонка (коментар) має бути порожньою, бо заголовок системний
      expect(
        csv.endsWith(','),
        false,
      ); // Перевірка, що після останньої коми нічого немає
      // Або точніше:
      final lines = csv.split('\n');
      final lastLineFields = lines[1].split(',');
      expect(lastLineFields.last.trim(), '');
    });

    test('Повинен зберігати користувацькі коментарі', () {
      final txWithComment = Transaction(
        id: '3',
        fromId: 'acc_1',
        toId: 'exp_1',
        title: 'Dinner with friends',
        amount: 5000,
        date: DateTime(2026, 1, 1),
        currency: 'UAH',
        baseAmount: 5000,
        baseCurrency: 'UAH',
      );

      final csv = ExportImportService.generateCsvString(
        transactions: [txWithComment],
        allCategories: [uahAcc, foodExp],
      );

      expect(csv.contains('Dinner with friends'), true);
    });
  });
}
