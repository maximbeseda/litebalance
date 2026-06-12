import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/services/storage_service.dart';

void main() {
  late StorageService storageService;
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);

    // Створюємо базу в оперативній пам'яті для тестів
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('StorageService - SharedPreferences (Settings)', () {
    test('getBaseCurrency повертає дефолтне значення UAH', () {
      expect(storageService.getBaseCurrency(), 'UAH');
    });

    test('saveBaseCurrency реально зберігає значення', () async {
      await storageService.saveBaseCurrency('USD');
      expect(prefs.getString('base_currency'), 'USD');
      expect(storageService.getBaseCurrency(), 'USD');
    });

    test('ExchangeRates правильно десеріалізує дані', () async {
      final rates = {'USD': 40.5, 'EUR': 43.2};
      await storageService.saveExchangeRates(rates);

      final loadedRates = storageService.getExchangeRates();

      // Перевіряємо конкретні значення замість перевірки типу
      expect(loadedRates['USD'], 40.5);
      expect(loadedRates['EUR'], 43.2);
    });
  });

  group('StorageService - Drift (Database)', () {
    const testCategory = Category(
      id: 'cat_test',
      name: 'Shopping',
      type: CategoryType.expense,
      currency: 'UAH',
      amount: 0,
      icon: 1,
      bgColor: 1,
      iconColor: 1,
      isArchived: false,
      includeInTotal: true,
      sortOrder: 0,
    );

    test('saveCategory та loadCategories працюють у зв\'язці', () async {
      await StorageService.saveCategory(db, testCategory);
      final categories = await StorageService.loadCategories(db);

      expect(categories.length, 1);
      expect(categories.first.name, 'Shopping');
    });

    test('InsertMode.replace оновлює існуючий запис, а не дублює', () async {
      await StorageService.saveCategory(db, testCategory);

      final updatedCategory = testCategory.copyWith(name: 'Updated Name');
      await StorageService.saveCategory(db, updatedCategory);

      final categories = await StorageService.loadCategories(db);
      expect(categories.length, 1);
      expect(categories.first.name, 'Updated Name');
    });

    test('wipeEntireDatabase очищує всі таблиці', () async {
      await StorageService.saveCategory(db, testCategory);
      await StorageService.wipeEntireDatabase(db);

      final categories = await StorageService.loadCategories(db);
      expect(categories.isEmpty, true);
    });
  });
}
