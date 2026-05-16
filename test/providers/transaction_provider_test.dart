import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/storage_service.dart';

// ==========================================
// 1. SPIES & FAKES
// ==========================================
class SpyTracker {
  static List<String> categoryUpdates = [];
  static void clear() => categoryUpdates.clear();
}

class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH', 'USD', 'JPY', 'ZERO'],
    // 👇 ВИПРАВЛЕНО: Правильні математичні пропорції
    exchangeRates: const {'UAH': 1.0, 'USD': 0.025, 'JPY': 4.0, 'ZERO': 0.0},
    historicalCache: const {},
    lastRatesUpdate: DateTime.now(),
  );

  // Спеціальний метод для тестування міграції
  void setBaseCurrencyTest(String newBase) {
    state = state.copyWith(baseCurrency: newBase);
  }

  @override
  Future<double?> getRateForDate(String currencyCode, DateTime date) async {
    if (currencyCode == 'UAH') return 1.0;
    // 👇 ВИПРАВЛЕНО: 1 UAH = 0.025 USD
    if (currencyCode == 'USD') return 0.025;
    // 👇 ВИПРАВЛЕНО: 1 UAH = 4 JPY
    if (currencyCode == 'JPY') return 4.0;
    if (currencyCode == 'ZERO') return 0.0;
    return 1.0;
  }
}

class TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [],
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
// 2. MAIN TESTS
// ==========================================
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SpyTracker.clear();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
      ],
    );
  });

  tearDown(() async {
    // Запобіжник гонки даних перед закриттям SQLite
    await Future.delayed(const Duration(milliseconds: 50));
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

  Future<TransactionNotifier> getSafeNotifier() async {
    await container.read(transactionProvider.future);
    await Future.delayed(
      const Duration(milliseconds: 10),
    ); // Даємо час слухачам
    return container.read(transactionProvider.notifier);
  }

  group('TransactionNotifier - State & UI (Місяці)', () {
    test(
      'isCurrentMonth працює коректно, setMonth і changeMonth змінюють стан',
      () async {
        final notifier = await getSafeNotifier();

        // Перевіряємо setMonth
        final pastMonth = DateTime(2022, 5, 1);
        notifier.setMonth(pastMonth);
        expect(
          container.read(transactionProvider).value!.selectedMonth,
          pastMonth,
        );
        expect(
          container.read(transactionProvider).value!.isCurrentMonth,
          false,
        );

        // Перевіряємо changeMonth (+1 місяць)
        notifier.changeMonth(1);
        expect(
          container.read(transactionProvider).value!.selectedMonth,
          DateTime(2022, 6, 1),
        );

        // Перевіряємо changeMonth (-2 місяці)
        notifier.changeMonth(-2);
        expect(
          container.read(transactionProvider).value!.selectedMonth,
          DateTime(2022, 4, 1),
        );
      },
    );
  });

  group('TransactionNotifier - Core Operations & Edge Cases', () {
    test(
      'addTransactionDirectly: пропускає розрахунок, якщо валюти збігаються і baseAmount != 0',
      () async {
        final notifier = await getSafeNotifier();

        // Створюємо транзакцію з базовою валютою
        final directTx = txBase.copyWith(
          amount: 500,
          baseAmount: 500,
          baseCurrency: 'UAH',
          currency: 'UAH',
        );
        await notifier.addTransactionDirectly(directTx);

        final state = container.read(transactionProvider).value!;
        expect(
          state.history.first.baseAmount,
          500,
        ); // Не має робити запит до rate
      },
    );

    test(
      'addTransfer: таргет сума = baseAmount, якщо цільова валюта дорівнює базовій',
      () async {
        final notifier = await getSafeNotifier();
        const sourceCat = Category(
          id: 'acc_1',
          name: 'S',
          type: CategoryType.account,
          currency: 'USD',
          amount: 0,
          icon: 0,
          bgColor: 0,
          iconColor: 0,
          isArchived: false,
          includeInTotal: true,
          sortOrder: 0,
        );
        const targetCat = Category(
          id: 'acc_2',
          name: 'T',
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
          targetAmount: 4000,
        );

        final state = container.read(transactionProvider).value!;
        // Оскільки targetCurrency (UAH) == baseCurrency (UAH), baseAmount має дорівнювати targetAmount
        expect(state.history.first.baseAmount, 4000);
      },
    );

    test(
      'editTransaction: якщо previousAmount == 0 (захист від ділення на нуль)',
      () async {
        final zeroTx = txBase.copyWith(
          amount: 0,
          targetAmount: const drift.Value(0),
        );
        await StorageService.saveTransaction(db, zeroTx);

        final notifier = await getSafeNotifier();

        // Редагуємо транзакцію, де минула сума була 0
        await notifier.editTransaction(zeroTx, 1000, defaultDate);

        final state = container.read(transactionProvider).value!;
        expect(state.history.first.amount, 1000);
        expect(
          state.history.first.baseAmount,
          1000,
        ); // Розраховано заново, без ділення на нуль
      },
    );

    test(
      'calculateBaseAmountAsync: якщо курс дорівнює нулю (захист)',
      () async {
        final notifier = await getSafeNotifier();
        final zeroRateTx = txBase.copyWith(
          amount: 1000,
          currency: 'ZERO',
          baseAmount: 0,
        );

        await notifier.addTransactionDirectly(zeroRateTx);

        final state = container.read(transactionProvider).value!;
        // Оскільки fromRate == 0 (fallback to 1.0), 1000 * (1.0 / 1.0) = 1000
        expect(state.history.first.baseAmount, 1000);
      },
    );
  });

  group('TransactionNotifier - Lifecycle, Trash & Delete', () {
    test('moveToTrash, restoreFromTrash та deletePermanently', () async {
      await StorageService.saveTransaction(db, txBase);
      final notifier = await getSafeNotifier();

      // 1. Move to trash
      await notifier.moveToTrash(txBase);
      var state = container.read(transactionProvider).value!;
      expect(state.history.isEmpty, true);
      expect(state.deletedHistory.length, 1);
      expect(
        SpyTracker.categoryUpdates,
        contains('acc_1:1000'),
      ); // Повернули гроші

      // 2. Restore
      SpyTracker.clear();
      await notifier.restoreFromTrash(state.deletedHistory.first);
      state = container.read(transactionProvider).value!;
      expect(state.history.length, 1);
      expect(state.deletedHistory.isEmpty, true);
      expect(
        SpyTracker.categoryUpdates,
        contains('acc_1:-1000'),
      ); // Знову зняли гроші

      // 3. Delete Permanently
      await notifier.deletePermanently(state.history.first);
      state = container.read(transactionProvider).value!;
      expect(state.history.isEmpty, true);
      expect(state.deletedHistory.isEmpty, true);

      final dbData = await StorageService.loadHistory(db);
      expect(dbData.isEmpty, true);
    });

    test('clearAllTransactions очищає базу', () async {
      await StorageService.saveTransaction(db, txBase);
      final notifier = await getSafeNotifier();

      await notifier.clearAllTransactions();
      final state = container.read(transactionProvider).value!;

      expect(state.history.isEmpty, true);
      final dbData = await StorageService.loadHistory(db);
      expect(dbData.isEmpty, true);
    });
  });

  group('TransactionNotifier - Background Migration', () {
    test(
      'Зміна baseCurrency у налаштуваннях тригерить перерахунок поточного місяця',
      () async {
        final now = DateTime.now();
        final currentMonthTx = txBase.copyWith(
          id: 'tx_now',
          date: now,
          amount: 100,
          currency: 'USD',
          baseCurrency: 'UAH',
          baseAmount: 4000,
        );
        final oldTx = txBase.copyWith(
          id: 'tx_old',
          date: DateTime(2020, 1, 1),
          amount: 100,
          currency: 'USD',
          baseCurrency: 'UAH',
          baseAmount: 4000,
        );

        await StorageService.saveTransaction(db, currentMonthTx);
        await StorageService.saveTransaction(db, oldTx);

        await getSafeNotifier();

        // Імітуємо зміну валюти в налаштуваннях (UAH -> JPY)
        final settings =
            container.read(settingsProvider.notifier) as TestSettingsNotifier;
        settings.setBaseCurrencyTest(
          'JPY',
        ); // 1 USD = 40 UAH. 1 UAH = 4 JPY. -> 1 USD = 160 JPY

        // Даємо час слухачу ref.listen відпрацювати і запустити міграцію
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(transactionProvider).value!;

        // Транзакція поточного місяця МАЄ змінити baseCurrency та baseAmount
        final updatedTx = state.history.firstWhere((t) => t.id == 'tx_now');
        expect(updatedTx.baseCurrency, 'JPY');
        expect(
          updatedTx.baseAmount,
          16000,
        ); // 100 USD -> 160 JPY -> 16000 (в копійках)

        // Стара транзакція залишається недоторканою
        final ignoredTx = state.history.firstWhere((t) => t.id == 'tx_old');
        expect(ignoredTx.baseCurrency, 'UAH');
        expect(ignoredTx.baseAmount, 4000);
      },
    );

    test(
      'Міграція ігнорується, якщо в поточному місяці немає транзакцій',
      () async {
        await getSafeNotifier();

        final settings =
            container.read(settingsProvider.notifier) as TestSettingsNotifier;
        settings.setBaseCurrencyTest('USD');
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(transactionProvider).value!;
        expect(
          state.lastKnownBaseCurrency,
          'USD',
        ); // Лише зберіг поточну валюту
        expect(state.isMigrating, false);
      },
    );
  });
}
