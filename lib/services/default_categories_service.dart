import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../theme/category_defaults.dart';

/// Сервіс для створення базових категорій при першому запуску додатка
class DefaultCategoriesService {
  static const _uuid = Uuid();

  /// Створює базові категорії якщо база даних порожня
  ///
  /// [db] - інстанс бази даних
  /// [languageCode] - код мови ('uk', 'en', 'de')
  /// [currencyCode] - код валюти (наприклад 'UAH', 'USD')
  static Future<void> createDefaultCategories(
    AppDatabase db,
    String languageCode,
    String currencyCode,
  ) async {
    // Перевіряємо чи база порожня
    final existingCategories = await db.select(db.categories).get();
    if (existingCategories.isNotEmpty) {
      return; // База не порожня, нічого не робимо
    }

    // Отримуємо переклади для поточної мови
    final salary = 'default_category_salary'.tr();
    final cash = 'default_category_cash'.tr();
    final card = 'default_category_card'.tr();
    final transport = 'default_category_transport'.tr();
    final food = 'default_category_food'.tr();
    final shopping = 'default_category_shopping'.tr();

    // Створюємо список базових категорій
    final defaultCategories = <CategoriesCompanion>[
      // Дохід: Зарплата
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.income,
        name: salary,
        icon: Icons.account_balance_wallet.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.income).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.income).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(0),
      ),

      // Рахунки: Готівка
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.account,
        name: cash,
        icon: Icons.wallet.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.account).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.account).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(0),
      ),

      // Рахунки: Картка
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.account,
        name: card,
        icon: Icons.credit_card.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.account).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.account).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(1),
      ),

      // Витрати: Транспорт
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.expense,
        name: transport,
        icon: Icons.directions_car.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.expense).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.expense).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(0),
      ),

      // Витрати: Їжа
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.expense,
        name: food,
        icon: Icons.restaurant.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.expense).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.expense).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(1),
      ),

      // Витрати: Покупки
      CategoriesCompanion.insert(
        id: _uuid.v4(),
        type: CategoryType.expense,
        name: shopping,
        icon: Icons.shopping_bag.codePoint,
        bgColor: CategoryDefaults.getBgColor(CategoryType.expense).toARGB32(),
        iconColor: CategoryDefaults.getIconColor(CategoryType.expense).toARGB32(),
        amount: const Value(0),
        currency: Value(currencyCode),
        sortOrder: const Value(2),
      ),
    ];

    // Зберігаємо всі категорії в базу даних
    await db.batch((batch) {
      batch.insertAll(db.categories, defaultCategories);
    });
  }
}
