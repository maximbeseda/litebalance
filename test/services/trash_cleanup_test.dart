import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/storage_service.dart';
import 'package:litebalance/services/trash_cleanup.dart';

// Мінімальні фейки, щоб TrashCleanup міг прочитати провайдери. Реально тест
// вправляє лише гілку підписок (у категорій/транзакцій кошик порожній).
class _SpyTransactionNotifier extends TransactionNotifier {
  @override
  Future<TransactionState> build() async => TransactionState(
    history: const [],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );
}

class _TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [],
    accounts: const [],
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );
}

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH'],
    exchangeRates: const {'UAH': 1.0},
    historicalCache: const {},
  );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  Future<ProviderContainer> createContainer() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        transactionProvider.overrideWith(() => _SpyTransactionNotifier()),
        categoryProvider.overrideWith(() => _TestCategoryNotifier()),
        settingsProvider.overrideWith(() => _TestSettingsNotifier()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return container;
  }

  Subscription deletedSub(String id, DateTime deletedAt) => Subscription(
    id: id,
    name: id,
    amount: 100,
    currency: 'UAH',
    accountId: 'acc',
    categoryId: 'exp',
    periodicity: 'monthly',
    nextPaymentDate: DateTime.now().add(const Duration(days: 30)),
    isAutoPay: false,
    deletedAt: deletedAt,
  );

  Future<bool> runCleanup(ProviderContainer c) => TrashCleanup.run(
    categoryState: c.read(categoryProvider),
    categoryNotifier: c.read(categoryProvider.notifier),
    transactionState: c.read(transactionProvider).value,
    transactionNotifier: c.read(transactionProvider.notifier),
    subscriptionState: c.read(subscriptionProvider).value,
    subscriptionNotifier: c.read(subscriptionProvider.notifier),
  );

  test('видаляє лише прострочені (≥30 днів) елементи, свіжі лишає', () async {
    final container = await createContainer();
    final now = DateTime.now();

    final old = deletedSub('sub_old', now.subtract(const Duration(days: 40)));
    final fresh = deletedSub('sub_fresh', now.subtract(const Duration(days: 5)));
    await StorageService.saveSubscription(db, old);
    await StorageService.saveSubscription(db, fresh);

    final notifier = container.read(subscriptionProvider.notifier);
    await Future.delayed(Duration.zero);
    await notifier.loadSubscriptions();

    expect(
      container.read(subscriptionProvider).value!.deletedSubscriptions.length,
      2,
    );

    final changed = await runCleanup(container);
    expect(changed, true);

    final remaining = container
        .read(subscriptionProvider)
        .value!
        .deletedSubscriptions;
    expect(remaining.map((s) => s.id).toList(), ['sub_fresh']);
  });

  test('нічого не видаляє, якщо прострочених немає', () async {
    final container = await createContainer();
    final now = DateTime.now();

    await StorageService.saveSubscription(
      db,
      deletedSub('sub_fresh', now.subtract(const Duration(days: 10))),
    );

    final notifier = container.read(subscriptionProvider.notifier);
    await Future.delayed(Duration.zero);
    await notifier.loadSubscriptions();

    final changed = await runCleanup(container);
    expect(changed, false);
    expect(
      container.read(subscriptionProvider).value!.deletedSubscriptions.length,
      1,
    );
  });
}
