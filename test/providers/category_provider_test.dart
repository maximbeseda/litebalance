import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/storage_service.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // 👇 Використовуємо const для базового об'єкта, щоб задовольнити лінтер
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

  group('CategoryNotifier - Load & Distribute', () {
    test(
      'Повинен правильно розподіляти категорії по списках (Active/Archived/Deleted)',
      () async {
        // 1. Активний рахунок
        const activeAcc = catBase;

        // 2. Архівний дохід
        const archivedInc = Category(
          id: 'cat_2',
          name: 'Bonus',
          type: CategoryType.income,
          currency: 'USD',
          amount: 0,
          icon: 0,
          bgColor: 0,
          iconColor: 0,
          isArchived: true, // Архівний
          includeInTotal: true,
          sortOrder: 1,
        );

        // 3. Видалена витрата (в кошику) - тут const неможливий через DateTime.now()
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

        final notifier = container.read(categoryProvider.notifier);
        await notifier.loadCategories();

        final state = container.read(categoryProvider);

        expect(state.accounts.length, 1);
        expect(state.accounts.first.id, 'cat_1');
        expect(state.incomes.isEmpty, true);
        expect(state.archivedCategories.length, 1);
        expect(state.archivedCategories.first.id, 'cat_2');
        expect(state.deletedCategories.length, 1);
        expect(state.deletedCategories.first.id, 'cat_3');
      },
    );
  });

  group('CategoryNotifier - Lifecycle (Trash & Archive)', () {
    test(
      'moveToTrash повинен ставити deletedAt і переміщати в кошик',
      () async {
        await StorageService.saveCategory(db, catBase);
        final notifier = container.read(categoryProvider.notifier);
        await notifier.loadCategories();

        await notifier.moveToTrash(catBase);

        final state = container.read(categoryProvider);
        expect(state.accounts.isEmpty, true);
        expect(state.deletedCategories.length, 1);
        expect(state.deletedCategories.first.id, 'cat_1');
        expect(state.deletedCategories.first.deletedAt, isNotNull);
      },
    );

    test(
      'emptyTrashOrArchive: Фізичне видалення, якщо НЕМАЄ транзакцій',
      () async {
        final trashedCat = catBase.copyWith(
          deletedAt: drift.Value(DateTime.now()),
        );
        await StorageService.saveCategory(db, trashedCat);

        final notifier = container.read(categoryProvider.notifier);
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
          toId: 'some_other_id',
          title: 'Test',
          amount: 100,
          date: DateTime.now(),
          currency: 'USD',
          targetAmount: null,
          targetCurrency: null,
          baseAmount: 100,
          baseCurrency: 'USD',
        );
        await StorageService.saveTransaction(db, tx);

        final notifier = container.read(categoryProvider.notifier);
        await notifier.loadCategories();

        await notifier.emptyTrashOrArchive(trashedCat);

        final state = container.read(categoryProvider);

        expect(state.deletedCategories.isEmpty, true);
        expect(state.archivedCategories.length, 1);
        expect(state.archivedCategories.first.isArchived, true);
        expect(state.archivedCategories.first.deletedAt, isNull);
      },
    );
  });

  group('CategoryNotifier - Balance Update', () {
    test(
      'updateCategoryAmount повинен коректно додавати та віднімати баланс',
      () async {
        await StorageService.saveCategory(db, catBase);
        final notifier = container.read(categoryProvider.notifier);
        await notifier.loadCategories();

        notifier.updateCategoryAmount('cat_1', 200);
        expect(container.read(categoryProvider).accounts.first.amount, 700);

        notifier.updateCategoryAmount('cat_1', -1000);
        expect(container.read(categoryProvider).accounts.first.amount, -300);
      },
    );
  });
}
