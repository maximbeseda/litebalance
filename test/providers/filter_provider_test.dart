import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/storage_service.dart';

// ==========================================
// 1. SPIES & FAKES
// ==========================================
class TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [],
    accounts: const [
      Category(
        id: 'acc_1',
        name: 'Monobank',
        type: CategoryType.account,
        currency: 'UAH',
        amount: 0,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: false,
        includeInTotal: true,
        sortOrder: 0,
      ),
    ],
    expenses: const [
      Category(
        id: 'exp_1',
        name: 'Groceries',
        type: CategoryType.expense,
        currency: 'UAH',
        amount: 0,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: false,
        includeInTotal: true,
        sortOrder: 1,
      ),
    ],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );
}

class DummyTransactionNotifier extends TransactionNotifier {
  @override
  Future<TransactionState> build() async => TransactionState(
    history: const [],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  Future<ProviderContainer> createContainer() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (db) {
          db.createFunction(
            functionName: 'dart_lower',
            function: (args) {
              if (args.isNotEmpty && args[0] is String) {
                return (args[0] as String).toLowerCase();
              }
              return args.isEmpty ? null : args[0];
            },
          );
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
        transactionProvider.overrideWith(() => DummyTransactionNotifier()),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    return container;
  }

  // 💡 Використовуємо гарантовану затримку: 300мс (debounce) + 1200мс (на виконання SQL)
  Future<void> awaitSearchEventLoop() async {
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  group('FilterNotifier - Fuzzy Search', () {
    test(
      'Повинен знаходити транзакції за назвою, категорією, сумою та датою',
      () async {
        final container = await createContainer();

        // 👇 МАГІЯ: Підключаємо фейкового слухача, щоб Riverpod не вбив AutoDispose-провайдер
        container.listen(filterProvider, (_, _) {});

        // Зберігаємо категорії в тестову БД
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'exp_1',
                type: CategoryType.expense,
                name: 'Groceries',
                icon: 0,
                bgColor: 0,
                iconColor: 0,
              ),
            );
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: 'acc_1',
                type: CategoryType.account,
                name: 'Monobank',
                icon: 0,
                bgColor: 0,
                iconColor: 0,
              ),
            );

        final tx = Transaction(
          id: 'tx_search_1',
          fromId: 'acc_1',
          toId: 'exp_1',
          title: 'Silpo Supermarket',
          amount: 15050,
          date: DateTime(2026, 10, 12, 12),
          currency: 'UAH',
          targetAmount: null,
          targetCurrency: null,
          baseAmount: 15050,
          baseCurrency: 'UAH',
        );

        await StorageService.saveTransaction(db, tx);

        final notifier = container.read(filterProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 100));

        notifier.setSearchQuery('silpo');
        await awaitSearchEventLoop();
        expect(
          container.read(filterProvider).results.length,
          1,
          reason: "SQL запит не знайшов транзакцію за словом 'silpo'",
        );

        notifier.setSearchQuery('groc');
        await awaitSearchEventLoop();
        expect(
          container.read(filterProvider).results.length,
          1,
          reason: "SQL запит не знайшов транзакцію за категорією 'groc'",
        );

        notifier.setSearchQuery('150.50');
        await awaitSearchEventLoop();
        expect(
          container.read(filterProvider).results.length,
          1,
          reason: "SQL запит не знайшов транзакцію за сумою '150.50'",
        );

        notifier.setSearchQuery('10.2026');
        await awaitSearchEventLoop();
        expect(
          container.read(filterProvider).results.length,
          1,
          reason: "SQL запит не знайшов транзакцію за датою '10.2026'",
        );

        notifier.setSearchQuery('non_existent_data');
        await awaitSearchEventLoop();
        expect(container.read(filterProvider).results.isEmpty, true);
      },
    );
  });

  group('FilterNotifier - Pagination Logic', () {
    test(
      'Повинен завантажувати по 30 елементів та зупинятися, коли дані закінчилися',
      () async {
        final container = await createContainer();

        container.listen(filterProvider, (_, _) {});

        final List<Transaction> batch = List.generate(
          35,
          (i) => Transaction(
            id: 'tx_$i',
            fromId: 'acc_1',
            toId: 'exp_1',
            title: 'Test $i',
            amount: 100,
            date: DateTime.now(),
            currency: 'UAH',
            targetAmount: null,
            targetCurrency: null,
            baseAmount: 100,
            baseCurrency: 'UAH',
          ),
        );

        for (var tx in batch) {
          await StorageService.saveTransaction(db, tx);
        }

        final notifier = container.read(filterProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        notifier.initGeneral();
        await Future.delayed(const Duration(milliseconds: 300));

        var state = container.read(filterProvider);
        expect(state.results.length, 30);
        expect(state.hasMore, true);
        expect(state.currentPage, 1);

        await notifier.loadNextPage();
        await Future.delayed(const Duration(milliseconds: 300));

        state = container.read(filterProvider);
        expect(state.results.length, 35);
        expect(state.hasMore, false);
        expect(state.currentPage, 2);
      },
    );
  });

  group('FilterNotifier - Filter State Reset', () {
    test('clearAllFilters повинен скидати дати, валюту та тип', () async {
      final container = await createContainer();

      container.listen(filterProvider, (_, _) {});

      final notifier = container.read(filterProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.setDateRange(DateTime.now(), DateTime.now());
      notifier.setCurrency('USD');

      await Future.delayed(const Duration(milliseconds: 50));

      var state = container.read(filterProvider);
      expect(state.startDate, isNotNull);
      expect(state.selectedCurrency, 'USD');

      notifier.clearAllFilters();
      await Future.delayed(const Duration(milliseconds: 50));

      state = container.read(filterProvider);
      expect(state.startDate, isNull);
      expect(state.selectedCurrency, isNull);
      expect(state.selectedType, isNull);
    });
  });
}
