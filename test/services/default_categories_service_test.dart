import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/services/default_categories_service.dart';
import 'package:coin_flow/theme/category_defaults.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    // Створюємо базу в оперативній пам'яті для тестів
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('DefaultCategoriesService', () {
    test('створює 6 базових категорій для порожньої бази', () async {
      // Перевіряємо що база порожня
      var categories = await db.select(db.categories).get();
      expect(categories.length, 0);

      // Створюємо базові категорії (переклади не важливі для тесту)
      // Викликаємо сервіс напряму, EasyLocalization буде використовувати fallback ключі
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      // Перевіряємо що створилось 6 категорій
      categories = await db.select(db.categories).get();
      expect(categories.length, 6);

      // Перевіряємо типи категорій
      final incomes = categories.where((c) => c.type == CategoryType.income).toList();
      final accounts = categories.where((c) => c.type == CategoryType.account).toList();
      final expenses = categories.where((c) => c.type == CategoryType.expense).toList();

      expect(incomes.length, 1, reason: 'Має бути 1 категорія доходів');
      expect(accounts.length, 2, reason: 'Мають бути 2 рахунки');
      expect(expenses.length, 3, reason: 'Мають бути 3 категорії витрат');

      // Перевіряємо що всі мають назви (не порожні)
      expect(categories.every((c) => c.name.isNotEmpty), true);

      // Перевіряємо валюту
      expect(categories.every((c) => c.currency == 'UAH'), true);

      // Перевіряємо початковий баланс
      expect(categories.every((c) => c.amount == 0), true);
    });

    test('створює категорії з правильною валютою USD', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'en', 'USD');

      final categories = await db.select(db.categories).get();
      expect(categories.length, 6);

      // Перевіряємо валюту
      expect(categories.every((c) => c.currency == 'USD'), true);
    });

    test('створює категорії з правильною валютою EUR', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'de', 'EUR');

      final categories = await db.select(db.categories).get();
      expect(categories.length, 6);

      // Перевіряємо валюту
      expect(categories.every((c) => c.currency == 'EUR'), true);
    });

    test('НЕ створює категорії якщо база вже має дані', () async {
      // Додаємо одну категорію вручну
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'existing_cat',
          type: CategoryType.expense,
          name: 'Existing Category',
          icon: 123,
          bgColor: 456,
          iconColor: 789,
        ),
      );

      // Перевіряємо що є 1 категорія
      var categories = await db.select(db.categories).get();
      expect(categories.length, 1);

      // Пробуємо створити базові категорії
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      // Перевіряємо що кількість не змінилась
      categories = await db.select(db.categories).get();
      expect(categories.length, 1);
      expect(categories.first.name, 'Existing Category');
    });

    test('перевіряє правильність іконок для категорій', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();

      // Знаходимо категорії за типом і sortOrder
      final income = categories.firstWhere(
        (c) => c.type == CategoryType.income && c.sortOrder == 0,
      );
      expect(income.icon, Icons.account_balance_wallet.codePoint);

      final accounts = categories
          .where((c) => c.type == CategoryType.account)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(accounts[0].icon, Icons.wallet.codePoint); // Готівка
      expect(accounts[1].icon, Icons.credit_card.codePoint); // Картка

      final expenses = categories
          .where((c) => c.type == CategoryType.expense)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(expenses[0].icon, Icons.directions_car.codePoint); // Транспорт
      expect(expenses[1].icon, Icons.restaurant.codePoint); // Їжа
      expect(expenses[2].icon, Icons.shopping_bag.codePoint); // Покупки
    });

    test('перевіряє правильність кольорів для кожного типу', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();

      final incomes = categories.where((c) => c.type == CategoryType.income).toList();
      final accounts = categories.where((c) => c.type == CategoryType.account).toList();
      final expenses = categories.where((c) => c.type == CategoryType.expense).toList();

      // Перевіряємо кольори доходів
      for (var income in incomes) {
        expect(
          income.bgColor,
          CategoryDefaults.getBgColor(CategoryType.income).toARGB32(),
        );
        expect(
          income.iconColor,
          CategoryDefaults.getIconColor(CategoryType.income).toARGB32(),
        );
      }

      // Перевіряємо кольори рахунків
      for (var account in accounts) {
        expect(
          account.bgColor,
          CategoryDefaults.getBgColor(CategoryType.account).toARGB32(),
        );
        expect(
          account.iconColor,
          CategoryDefaults.getIconColor(CategoryType.account).toARGB32(),
        );
      }

      // Перевіряємо кольори витрат
      for (var expense in expenses) {
        expect(
          expense.bgColor,
          CategoryDefaults.getBgColor(CategoryType.expense).toARGB32(),
        );
        expect(
          expense.iconColor,
          CategoryDefaults.getIconColor(CategoryType.expense).toARGB32(),
        );
      }
    });

    test('перевіряє правильність sortOrder для категорій', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();

      // Перевіряємо sortOrder для доходів (має бути 0)
      final incomes = categories.where((c) => c.type == CategoryType.income).toList();
      expect(incomes.first.sortOrder, 0);

      // Перевіряємо sortOrder для рахунків (0 та 1)
      final accounts = categories
          .where((c) => c.type == CategoryType.account)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(accounts.length, 2);
      expect(accounts[0].sortOrder, 0);
      expect(accounts[1].sortOrder, 1);

      // Перевіряємо sortOrder для витрат (0, 1, 2)
      final expenses = categories
          .where((c) => c.type == CategoryType.expense)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(expenses.length, 3);
      expect(expenses[0].sortOrder, 0);
      expect(expenses[1].sortOrder, 1);
      expect(expenses[2].sortOrder, 2);
    });

    test('перевіряє що всі категорії мають унікальні ID', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();
      final ids = categories.map((c) => c.id).toList();

      // Перевіряємо що всі ID унікальні
      expect(ids.length, ids.toSet().length);

      // Перевіряємо що ID не порожні та мають формат UUID
      expect(ids.every((id) => id.isNotEmpty), true);
      expect(ids.every((id) => id.length > 10), true); // UUID мінімум 36 символів
    });

    test('перевіряє що всі обов\'язкові поля заповнені', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();

      for (var category in categories) {
        expect(category.id.isNotEmpty, true, reason: 'ID не може бути порожнім');
        expect(category.name.isNotEmpty, true, reason: 'Назва не може бути порожньою');
        expect(category.icon > 0, true, reason: 'Icon codePoint має бути > 0');
        expect(category.bgColor > 0, true, reason: 'bgColor має бути > 0');
        expect(category.iconColor > 0, true, reason: 'iconColor має бути > 0');
        expect(category.currency.isNotEmpty, true, reason: 'Валюта не може бути порожньою');
        expect(category.sortOrder >= 0, true, reason: 'sortOrder має бути >= 0');
      }
    });

    test('перевіряє що категорії мають правильні дефолтні значення', () async {
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');

      final categories = await db.select(db.categories).get();

      for (var category in categories) {
        expect(category.amount, 0, reason: 'Початковий баланс має бути 0');
        expect(category.isArchived, false, reason: 'Категорія не має бути архівованою');
        expect(category.includeInTotal, true, reason: 'Категорія має включатись у загальний баланс');
        expect(category.deletedAt, null, reason: 'Категорія не має бути видаленою');
        expect(category.budget, null, reason: 'Бюджет за замовчуванням має бути null');
      }
    });

    test('множинний виклик не створює дублікати', () async {
      // Перший виклик
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');
      var categories = await db.select(db.categories).get();
      expect(categories.length, 6);

      // Другий виклик
      await DefaultCategoriesService.createDefaultCategories(db, 'uk', 'UAH');
      categories = await db.select(db.categories).get();
      expect(categories.length, 6, reason: 'Повторний виклик не має створювати дублікати');

      // Третій виклик з іншими параметрами
      await DefaultCategoriesService.createDefaultCategories(db, 'en', 'USD');
      categories = await db.select(db.categories).get();
      expect(categories.length, 6, reason: 'Виклик з іншими параметрами теж не має створювати дублікати');
    });
  });
}
