import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/storage_service.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    // 👇 ЗАПОБІЖНИК №1: Чекаємо 50мс перед закриттям бази.
    // Це дає час усім фоновим "fire-and-forget" запитам (як у reorderCategories)
    // успішно зберегтися в базу ДО того, як ми її закриємо.
    await Future.delayed(const Duration(milliseconds: 50));
    container.dispose();
    await db.close();
  });

  const catBase = Category(
    id: 'cat_1',
    name: 'Cash',
    type: CategoryType.account,
    currency: 'USD',
    amount: 500,
    icon: 0,
    bgColor: 0,
    iconColor: 0,
    isArchived: false,
    includeInTotal: true,
    sortOrder: 0,
  );

  // Хелпер для безпечного отримання провайдера без "гонки даних"
  Future<CategoryNotifier> getSafeNotifier() async {
    final notifier = container.read(categoryProvider.notifier);
    // 👇 ЗАПОБІЖНИК №2: Даємо час відпрацювати Future.microtask з методу build()
    await Future.delayed(const Duration(milliseconds: 50));
    return notifier;
  }

  group('CategoryNotifier - Load & Distribute', () {
    test('Повинен правильно розподіляти категорії по списках', () async {
      const activeAcc = catBase;
      const archivedInc = Category(
        id: 'cat_2',
        name: 'Bonus',
        type: CategoryType.income,
        currency: 'USD',
        amount: 0,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: true,
        includeInTotal: true,
        sortOrder: 1,
      );
      final deletedExp = catBase.copyWith(
        id: 'cat_3',
        type: CategoryType.expense,
        deletedAt: drift.Value(DateTime.now()),
      );

      await StorageService.saveCategories(db, [
        activeAcc,
        archivedInc,
        deletedExp,
      ]);

      final notifier = await getSafeNotifier();
      await notifier.loadCategories();

      final state = container.read(categoryProvider);

      expect(state.accounts.length, 1);
      expect(state.incomes.isEmpty, true);
      expect(state.archivedCategories.length, 1);
      expect(state.deletedCategories.length, 1);
    });
  });

  group('CategoryNotifier - Lifecycle (Trash, Archive, Restore)', () {
    test(
      'moveToTrash повинен ставити deletedAt і переміщати в кошик',
      () async {
        await StorageService.saveCategory(db, catBase);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        await notifier.moveToTrash(catBase);

        final state = container.read(categoryProvider);
        expect(state.accounts.isEmpty, true);
        expect(state.deletedCategories.length, 1);
        expect(state.deletedCategories.first.deletedAt, isNotNull);
      },
    );

    test(
      'restoreFromTrash повинен знімати deletedAt і повертати в активні',
      () async {
        final trashedCat = catBase.copyWith(
          deletedAt: drift.Value(DateTime.now()),
        );
        await StorageService.saveCategory(db, trashedCat);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        await notifier.restoreFromTrash(trashedCat);

        final state = container.read(categoryProvider);
        expect(state.deletedCategories.isEmpty, true);
        expect(state.accounts.length, 1);
        expect(state.accounts.first.deletedAt, isNull);
      },
    );

    test(
      'emptyTrashOrArchive: Фізичне видалення, якщо НЕМАЄ транзакцій',
      () async {
        final trashedCat = catBase.copyWith(
          deletedAt: drift.Value(DateTime.now()),
        );
        await StorageService.saveCategory(db, trashedCat);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        await notifier.emptyTrashOrArchive(trashedCat);

        final state = container.read(categoryProvider);
        expect(state.deletedCategories.isEmpty, true);

        final dbData = await StorageService.loadCategories(db);
        expect(dbData.isEmpty, true);
      },
    );

    test(
      'emptyTrashOrArchive: Переведення в архів, якщо Є транзакції',
      () async {
        final trashedCat = catBase.copyWith(
          deletedAt: drift.Value(DateTime.now()),
        );
        await StorageService.saveCategory(db, trashedCat);

        final tx = Transaction(
          id: 'tx_1',
          fromId: trashedCat.id,
          toId: 'other',
          title: 'Test',
          amount: 100,
          date: DateTime.now(),
          currency: 'USD',
          baseAmount: 100,
          baseCurrency: 'USD',
        );
        await StorageService.saveTransaction(db, tx);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        await notifier.emptyTrashOrArchive(trashedCat);

        final state = container.read(categoryProvider);
        expect(state.deletedCategories.isEmpty, true);
        expect(state.archivedCategories.length, 1);
        expect(state.archivedCategories.first.isArchived, true);
      },
    );
  });

  group('CategoryNotifier - Add, Update & Balance', () {
    test('addOrUpdateCategory додає нову категорію (Income)', () async {
      final notifier = await getSafeNotifier();
      await notifier.loadCategories();

      final newCat = catBase.copyWith(id: 'new_inc', type: CategoryType.income);
      await notifier.addOrUpdateCategory(newCat);

      final state = container.read(categoryProvider);
      expect(state.incomes.length, 1);
      expect(state.incomes.first.id, 'new_inc');
    });

    test('addOrUpdateCategory оновлює існуючу категорію (Expense)', () async {
      final expCat = catBase.copyWith(
        id: 'exp_1',
        type: CategoryType.expense,
        name: 'Old',
      );
      await StorageService.saveCategory(db, expCat);

      final notifier = await getSafeNotifier();
      await notifier.loadCategories();

      final updatedCat = expCat.copyWith(name: 'New Name');
      await notifier.addOrUpdateCategory(updatedCat);

      final state = container.read(categoryProvider);
      expect(state.expenses.length, 1);
      expect(state.expenses.first.name, 'New Name');
    });

    test(
      'updateCategoryAmount працює для всіх типів (Income, Account, Expense)',
      () async {
        final incCat = catBase.copyWith(
          id: 'inc_1',
          type: CategoryType.income,
          amount: 100,
        );
        final accCat = catBase.copyWith(
          id: 'acc_1',
          type: CategoryType.account,
          amount: 100,
        );
        final expCat = catBase.copyWith(
          id: 'exp_1',
          type: CategoryType.expense,
          amount: 100,
        );

        await StorageService.saveCategories(db, [incCat, accCat, expCat]);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        notifier.updateCategoryAmount('inc_1', 50);
        notifier.updateCategoryAmount('acc_1', -50);
        notifier.updateCategoryAmount('exp_1', 100);
        notifier.updateCategoryAmount('fake_id', 999);

        final state = container.read(categoryProvider);
        expect(state.incomes.first.amount, 150);
        expect(state.accounts.first.amount, 50);
        expect(state.expenses.first.amount, 200);
      },
    );
  });

  group('CategoryNotifier - Reorder & Batch Updates', () {
    test(
      'reorderCategories правильно міняє місцями і оновлює sortOrder',
      () async {
        final cat1 = catBase.copyWith(id: 'c1', name: 'A', sortOrder: 0);
        final cat2 = catBase.copyWith(id: 'c2', name: 'B', sortOrder: 1);
        final cat3 = catBase.copyWith(id: 'c3', name: 'C', sortOrder: 2);

        await StorageService.saveCategories(db, [cat1, cat2, cat3]);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        notifier.reorderCategories(cat1, cat3);

        final state = container.read(categoryProvider);
        expect(state.accounts[0].id, 'c2');
        expect(state.accounts[1].id, 'c3');
        expect(state.accounts[2].id, 'c1');
        expect(state.accounts[0].sortOrder, 0);
        expect(state.accounts[2].sortOrder, 2);
      },
    );

    test('reorderCategories ігнорує різні типи', () async {
      final acc = catBase.copyWith(id: 'a1', type: CategoryType.account);
      final exp = catBase.copyWith(id: 'e1', type: CategoryType.expense);

      await StorageService.saveCategories(db, [acc, exp]);

      final notifier = await getSafeNotifier();
      await notifier.loadCategories();

      notifier.reorderCategories(acc, exp);

      final state = container.read(categoryProvider);
      expect(state.accounts.first.id, 'a1');
      expect(state.expenses.first.id, 'e1');
    });

    test(
      'updateBaseCurrencyForCategories оновлює Incomes та Expenses, ігнорує Accounts',
      () async {
        final inc = catBase.copyWith(
          id: 'i1',
          type: CategoryType.income,
          currency: 'USD',
        );
        final acc = catBase.copyWith(
          id: 'a1',
          type: CategoryType.account,
          currency: 'USD',
        );
        final exp = catBase.copyWith(
          id: 'e1',
          type: CategoryType.expense,
          currency: 'EUR',
        );

        await StorageService.saveCategories(db, [inc, acc, exp]);

        final notifier = await getSafeNotifier();
        await notifier.loadCategories();

        await notifier.updateBaseCurrencyForCategories('USD', 'UAH');

        final state = container.read(categoryProvider);
        expect(state.incomes.first.currency, 'UAH');
        expect(state.accounts.first.currency, 'USD');
        expect(state.expenses.first.currency, 'EUR');
      },
    );

    test('resetAllBalances скидає суми всіх категорій в нуль', () async {
      final inc = catBase.copyWith(
        id: 'i1',
        type: CategoryType.income,
        amount: 500,
      );
      final acc = catBase.copyWith(
        id: 'a1',
        type: CategoryType.account,
        amount: 300,
      );
      final del = catBase.copyWith(
        id: 'd1',
        deletedAt: drift.Value(DateTime.now()),
        amount: 100,
      );

      await StorageService.saveCategories(db, [inc, acc, del]);

      final notifier = await getSafeNotifier();
      await notifier.loadCategories();

      await notifier.resetAllBalances();

      final state = container.read(categoryProvider);
      expect(state.incomes.first.amount, 0);
      expect(state.accounts.first.amount, 0);
      expect(state.deletedCategories.first.amount, 0);
    });
  });
}
