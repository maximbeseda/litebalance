import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/services/storage_service.dart';

// ==========================================
// 1. SPIES & FAKES
// ==========================================
class SpyTracker {
  // 👇 ФІКС 1: Використовуємо рядки замість Map, щоб уникнути проблеми з адресами пам'яті в Dart
  static List<String> categoryUpdates = [];
  static void clear() => categoryUpdates.clear();
}

class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH', 'USD', 'JPY'],
    exchangeRates: const {'UAH': 1.0, 'USD': 40.0, 'JPY': 0.25},
    historicalCache: const {},
    lastRatesUpdate: DateTime.now(),
  );

  @override
  Future<double?> getRateForDate(String currencyCode, DateTime date) async {
    if (currencyCode == 'UAH') return 1.0;
    if (currencyCode == 'USD') return 40.0;
    if (currencyCode == 'JPY') return 0.25;
    return 1.0;
  }
}

class TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [],
    // 👇 ФІКС 2: Даємо провайдеру реальні рахунки, щоб _updateAccountBalance їх знайшов!
    accounts: const [
      Category(
        id: 'acc_1',
        name: 'Card',
        type: CategoryType.account,
        currency: 'USD',
        amount: 500,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: false,
        includeInTotal: true,
        sortOrder: 0,
      ),
      Category(
        id: 'acc_2',
        name: 'Savings',
        type: CategoryType.account,
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
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  @override
  void updateCategoryAmount(String id, int delta) {
    SpyTracker.categoryUpdates.add('$id:$delta');
  }
}

// ==========================================
// 2. SETUP & FIXTURES
// ==========================================
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SpyTracker.clear();

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final defaultDate = DateTime(2026, 4, 25);

  final txBase = Transaction(
    id: 'tx_1',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Test Expense',
    amount: 1000,
    date: defaultDate,
    currency: 'UAH',
    targetAmount: null,
    targetCurrency: null,
    baseAmount: 1000,
    baseCurrency: 'UAH',
  );

  group('TransactionNotifier - Initialization & Load', () {
    test(
      'Повинен завантажити історію, відсортувати за датою та розділити на active/deleted',
      () async {
        final oldTx = txBase.copyWith(
          id: 'tx_old',
          date: defaultDate.subtract(const Duration(days: 10)),
        );
        final newTx = txBase.copyWith(id: 'tx_new', date: defaultDate);
        final deletedTx = txBase.copyWith(
          id: 'tx_del',
          deletedAt: drift.Value(defaultDate),
        );

        await StorageService.saveTransaction(db, oldTx);
        await StorageService.saveTransaction(db, newTx);
        await StorageService.saveTransaction(db, deletedTx);

        await container.read(transactionProvider.future);
        final state = container.read(transactionProvider).value!;

        expect(state.history.length, 2);
        expect(state.deletedHistory.length, 1);
        expect(state.history.first.id, 'tx_new');
        expect(state.history.last.id, 'tx_old');
      },
    );
  });

  group('TransactionNotifier - Core Operations (Integration Logic)', () {
    test(
      'addTransactionDirectly: розрахунок крос-курсу для базової валюти (JPY -> UAH)',
      () async {
        await container.read(transactionProvider.future);
        final notifier = container.read(transactionProvider.notifier);

        final jpyTx = txBase.copyWith(
          amount: 10000,
          currency: 'JPY',
          baseAmount: 0,
        );
        await notifier.addTransactionDirectly(jpyTx);

        final state = container.read(transactionProvider).value!;
        expect(state.history.length, 1);
        expect(state.history.first.baseAmount, 40000);

        final dbData = await StorageService.loadHistory(db);
        expect(dbData.first.baseAmount, 40000);

        // Використовуємо формат String для перевірки
        expect(SpyTracker.categoryUpdates, contains('acc_1:-10000'));
      },
    );

    test('addTransfer: мультивалютний переказ між рахунками', () async {
      await container.read(transactionProvider.future);
      final notifier = container.read(transactionProvider.notifier);

      const sourceCat = Category(
        id: 'acc_1',
        name: 'Card',
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
      const targetCat = Category(
        id: 'acc_2',
        name: 'Savings',
        type: CategoryType.account,
        currency: 'UAH',
        amount: 0,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: false,
        includeInTotal: true,
        sortOrder: 1,
      );

      await notifier.addTransfer(
        sourceCat,
        targetCat,
        100,
        defaultDate,
        targetAmount: 3950,
      );

      final state = container.read(transactionProvider).value!;
      final savedTx = state.history.first;

      expect(savedTx.amount, 100);
      expect(savedTx.targetAmount, 3950);
      expect(savedTx.baseAmount, 3950);

      expect(SpyTracker.categoryUpdates, contains('acc_1:-100'));
      expect(SpyTracker.categoryUpdates, contains('acc_2:3950'));
    });

    test('editTransaction: пропорційний перерахунок targetAmount', () async {
      final originalTx = txBase.copyWith(
        amount: 1000,
        targetAmount: const drift.Value(40),
        targetCurrency: const drift.Value('USD'),
      );
      await StorageService.saveTransaction(db, originalTx);

      await container.read(transactionProvider.future);
      final notifier = container.read(transactionProvider.notifier);

      await notifier.editTransaction(originalTx, 2000, defaultDate);

      final state = container.read(transactionProvider).value!;
      expect(state.history.first.amount, 2000);
      expect(state.history.first.targetAmount, 80);

      // Видалили очікування оновлень витрат (exp_1), бо ваш _updateAccountBalance перевіряє category.type == CategoryType.account!
      expect(
        SpyTracker.categoryUpdates,
        containsAllInOrder(['acc_1:1000', 'acc_1:-2000']),
      );
    });
  });

  group('TransactionNotifier - Lifecycle & Trash', () {
    test(
      'moveToTrash повинен реверснути баланси та оновити поле deletedAt',
      () async {
        await StorageService.saveTransaction(db, txBase);
        await container.read(transactionProvider.future);
        final notifier = container.read(transactionProvider.notifier);

        await notifier.moveToTrash(txBase);

        expect(SpyTracker.categoryUpdates, contains('acc_1:1000'));

        final dbData = await StorageService.loadHistory(db);
        expect(dbData.where((t) => t.deletedAt != null).length, 1);
      },
    );
  });
}
