import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:litebalance/providers/all_providers.dart';

// ==========================================
// 1. SPIES & FAKES
// ==========================================
class TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [
      Category(
        id: 'inc_1',
        name: 'Salary',
        type: CategoryType.income,
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
    accounts: const [
      Category(
        id: 'acc_1',
        name: 'Card UAH',
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
      Category(
        id: 'acc_2',
        name: 'Cash JPY',
        type: CategoryType.account,
        currency: 'JPY',
        amount: 0,
        icon: 0,
        bgColor: 0,
        iconColor: 0,
        isArchived: false,
        includeInTotal: true,
        sortOrder: 1,
      ),
    ],
    expenses: const [
      Category(
        id: 'exp_1',
        name: 'Food',
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
  final List<Transaction> initialHistory;
  DummyTransactionNotifier(this.initialHistory);

  @override
  Future<TransactionState> build() async => TransactionState(
    history: initialHistory,
    deletedHistory: const [],
    selectedMonth: DateTime(2026, 4),
    isMigrating: false,
  );
}

void main() {
  // Тестові транзакції
  final txIncome = Transaction(
    id: 'tx_1',
    fromId: 'inc_1',
    toId: 'acc_1',
    title: 'Salary',
    amount: 50000,
    date: DateTime(2026, 4, 10),
    currency: 'UAH',
    baseAmount: 50000,
    baseCurrency: 'UAH', // +500.00 UAH
  );

  final txExpense = Transaction(
    id: 'tx_2',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Groceries',
    amount: 15000,
    date: DateTime(2026, 4, 15),
    currency: 'UAH',
    baseAmount: 15000,
    baseCurrency: 'UAH', // -150.00 UAH
  );

  // Внутрішній переказ (не має впливати на доходи/витрати)
  final txTransfer = Transaction(
    id: 'tx_3',
    fromId: 'acc_1',
    toId: 'acc_2',
    title: 'Buy Yen',
    amount: 10000,
    targetAmount: 40000,
    date: DateTime(2026, 4, 20),
    currency: 'UAH',
    targetCurrency: 'JPY',
    baseAmount: 10000,
    baseCurrency: 'UAH', // Переказ 100 UAH в JPY
  );

  // Витрата в іншому місяці
  final txPastExpense = Transaction(
    id: 'tx_4',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Old Food',
    amount: 30000,
    date: DateTime(2026, 3, 5),
    currency: 'UAH',
    baseAmount: 30000,
    baseCurrency: 'UAH', // -300.00 UAH
  );

  // Транзакція, коли базовою валютою була JPY
  final txJpyExpense = Transaction(
    id: 'tx_5',
    fromId: 'acc_2',
    toId: 'exp_1',
    title: 'Sushi',
    amount: 5000,
    date: DateTime(2026, 4, 25),
    currency: 'JPY',
    baseAmount: 5000,
    baseCurrency: 'JPY', // -50.00 JPY
  );

  ProviderContainer createContainer(List<Transaction> history) {
    return ProviderContainer(
      overrides: [
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
        transactionProvider.overrideWith(
          () => DummyTransactionNotifier(history),
        ),
      ],
    );
  }

  group('StatsProvider - Monthly Totals', () {
    test(
      'calculateTotalsForMonth правильно рахує доходи/витрати та ігнорує перекази',
      () async {
        final container = createContainer([txIncome, txExpense, txTransfer]);
        final stats = container.read(statsProvider.notifier);

        // Чекаємо ініціалізації DummyTransactionNotifier
        await Future.delayed(Duration.zero);

        final totals = stats.calculateTotalsForMonth(DateTime(2026, 4));

        expect(totals['incomes'], 50000); // Тільки Зарплата
        expect(
          totals['expenses'],
          15000,
        ); // Тільки Продукти (Переказ ігнорується!)
      },
    );

    test(
      'calculateCategoryTotalsForMonth групує суми за категоріями',
      () async {
        final container = createContainer([txExpense, txPastExpense]);
        final stats = container.read(statsProvider.notifier);
        await Future.delayed(Duration.zero);

        // Перевіряємо квітень
        final aprilTotals = stats.calculateCategoryTotalsForMonth(
          DateTime(2026, 4),
          true,
        );
        expect(aprilTotals['exp_1'], 15000);

        // Перевіряємо березень
        final marchTotals = stats.calculateCategoryTotalsForMonth(
          DateTime(2026, 3),
          true,
        );
        expect(marchTotals['exp_1'], 30000);
      },
    );
  });

  group('StatsProvider - Trends & Epochs', () {
    test(
      'calculateTrends правильно розбиває по місяцях та базових валютах',
      () async {
        final container = createContainer([
          txIncome,
          txPastExpense,
          txJpyExpense,
        ]);
        final stats = container.read(statsProvider.notifier);
        await Future.delayed(Duration.zero);

        final trends = stats.calculateTrends();

        // Має бути дві "епохи" (UAH та JPY)
        expect(trends.containsKey('UAH'), true);
        expect(trends.containsKey('JPY'), true);

        // В епосі UAH: Квітень (дохід) та Березень (витрата)
        expect(trends['UAH']!['2026-04']!['incomes'], 50000);
        expect(trends['UAH']!['2026-04']!['expenses'], 0);

        expect(trends['UAH']!['2026-03']!['incomes'], 0);
        expect(trends['UAH']!['2026-03']!['expenses'], 30000);

        // В епосі JPY: Квітень (витрата)
        expect(trends['JPY']!['2026-04']!['expenses'], 5000);
      },
    );
  });
}
