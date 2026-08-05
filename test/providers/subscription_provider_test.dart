import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/storage_service.dart';

// ==========================================
// 1. SPIES & FAKES
// ==========================================
class SpyTransactionNotifier extends TransactionNotifier {
  List<Transaction> addedTransactions = [];

  // 👇 ФІКС 1: Додано Future та async, щоб відповідати оригінальному AsyncNotifier
  @override
  Future<TransactionState> build() async => TransactionState(
    history: const [],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );

  @override
  Future<void> addTransactionDirectly(Transaction tx) async {
    addedTransactions.add(tx);
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
        currency: 'UAH',
        amount: 10000,
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
        name: 'Subscriptions',
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

class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH', 'USD'],
    exchangeRates: const {'UAH': 1.0, 'USD': 40.0},
    historicalCache: const {},
  );
}

// ==========================================
// 2. SETUP & FIXTURES
// ==========================================
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
        transactionProvider.overrideWith(() => SpyTransactionNotifier()),
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    return container;
  }

  final subBase = Subscription(
    id: 'sub_1',
    name: 'Netflix',
    amount: 300,
    currency: 'UAH',
    accountId: 'acc_1',
    categoryId: 'exp_1',
    periodicity: 'monthly',
    nextPaymentDate: DateTime.now(),
    isAutoPay: false,
    // 👇 ФІКС 2: Видалено поле createdAt
  );

  group('SubscriptionNotifier - Date Math & AutoPay', () {
    test(
      'processAutoPayments: обробка кінця місяця (31 січня -> 28 лютого)',
      () async {
        final container = await createContainer();

        final jan31 = DateTime(2023, 1, 31);
        final autoPaySub = subBase.copyWith(
          id: 'sub_edge_case',
          nextPaymentDate: jan31,
          isAutoPay: true,
          // 👇 МАГІЯ: Ставимо суму 10 000, щоб "з'їсти" весь баланс за 1 раз
          // Тоді цикл зупиниться рівно на 28 лютого і не піде в 2026 рік!
          amount: 10000,
        );

        await StorageService.saveSubscription(db, autoPaySub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        final state = container.read(subscriptionProvider).value!;
        final updatedSub = state.subscriptions.first;

        // Тепер він має зупинитися рівно на 2-му місяці (Лютий)
        expect(updatedSub.nextPaymentDate.month, 2);
        expect(updatedSub.nextPaymentDate.day, 28);

        final txNotifier =
            container.read(transactionProvider.notifier)
                as SpyTransactionNotifier;
        expect(txNotifier.addedTransactions.length, 1);
        expect(
          txNotifier.addedTransactions.first.amount,
          10000,
        ); // Перевіряємо нову суму
      },
    );

    test(
      'Авто-підписка НІКОЛИ не потрапляє в dueSubscriptions (навіть коли бракує коштів)',
      () async {
        // Регресія: вранці, коли настала дата списання, авто-підписка не має
        // показувати діалог ручного підтвердження. Беремо суму більшу за баланс,
        // щоб processAutoPayments не зміг її обробити й вона лишилась простроченою —
        // вона все одно має бути виключена з due, бо isAutoPay = true.
        final container = await createContainer();

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final autoSub = subBase.copyWith(
          id: 'sub_auto_broke',
          nextPaymentDate: yesterday,
          isAutoPay: true,
          amount: 999999, // більше за баланс (10 000) -> авто не пройде
        );

        await StorageService.saveSubscription(db, autoSub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        final state = container.read(subscriptionProvider).value!;

        // Авто-списання не відбулось (бракує коштів), але діалог НЕ має тригеритись.
        expect(state.dueSubscriptions, isEmpty);

        final txNotifier =
            container.read(transactionProvider.notifier)
                as SpyTransactionNotifier;
        expect(txNotifier.addedTransactions, isEmpty);
      },
    );

    test(
      'hasPendingPayments: правильно визначає прострочені платежі',
      () async {
        final container = await createContainer();

        final pastDate = DateTime.now().subtract(const Duration(days: 5));
        final dueSub = subBase.copyWith(
          nextPaymentDate: pastDate,
          isAutoPay: false,
        );

        await StorageService.saveSubscription(db, dueSub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        final state = container.read(subscriptionProvider).value!;

        expect(state.hasPendingPayments, true);
        expect(state.dueSubscriptions.length, 1);
      },
    );

    test(
      'Перевірка кількості транзакцій: автооплата та ручне підтвердження працюють коректно',
      () async {
        final container = await createContainer();

        // Ставимо дату на вчора, щоб обидві підписки гарантовано потребували оплати
        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        // 1. Створюємо підписку з автооплатою
        final autoSub = subBase.copyWith(
          id: 'sub_auto',
          name: 'Spotify (Auto)',
          nextPaymentDate: yesterday,
          isAutoPay: true,
          amount: 150, // Сума для перевірки
        );

        // 2. Створюємо підписку з ручним підтвердженням
        final manualSub = subBase.copyWith(
          id: 'sub_manual',
          name: 'Gym (Manual)',
          nextPaymentDate: yesterday,
          isAutoPay: false,
          amount: 500, // Сума для перевірки
        );

        // Зберігаємо обидві в базу
        await StorageService.saveSubscription(db, autoSub);
        await StorageService.saveSubscription(db, manualSub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);

        // Виклик loadSubscriptions автоматично запускає processAutoPayments()
        await notifier.loadSubscriptions();

        final txNotifier =
            container.read(transactionProvider.notifier)
                as SpyTransactionNotifier;

        // ПЕРЕВІРКА 1: Автооплата мала відпрацювати і створити рівно 1 транзакцію
        expect(txNotifier.addedTransactions.length, 1);
        expect(txNotifier.addedTransactions.first.amount, 150);
        // У тестах easy_localization просто повертає сам ключ, якщо переклади не завантажені
        expect(
          txNotifier.addedTransactions.first.title.contains(
            'auto_payment_marker',
          ),
          true,
        );

        // ПЕРЕВІРКА 2: Ручна підписка мала потрапити у dueSubscriptions і чекати
        final state = container.read(subscriptionProvider).value!;
        expect(state.dueSubscriptions.length, 1);
        expect(state.dueSubscriptions.first.id, 'sub_manual');

        // ПЕРЕВІРКА 3: Робимо ручне підтвердження
        final (success, _) = await notifier.confirmSubscriptionPayment(
          state.dueSubscriptions.first,
          500,
        );
        expect(success, true);

        // ПЕРЕВІРКА 4: Тепер транзакцій має стати рівно 2
        expect(txNotifier.addedTransactions.length, 2);
        expect(txNotifier.addedTransactions.last.amount, 500);
        expect(txNotifier.addedTransactions.last.title, 'Gym (Manual)');
      },
    );

    test(
      'refreshOnAppResume списує прострочену авто-підписку (фікс гонки на відновленні)',
      () async {
        final container = await createContainer();

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final autoSub = subBase.copyWith(
          id: 'sub_auto_resume',
          name: 'Cloud (Auto)',
          nextPaymentDate: yesterday,
          isAutoPay: true,
          amount: 150,
        );
        await StorageService.saveSubscription(db, autoSub);

        // Читаємо провайдер, але НЕ викликаємо loadSubscriptions вручну —
        // саме refreshOnAppResume має надійно обробити автосписання.
        container.read(subscriptionProvider.notifier);

        await container
            .read(subscriptionProvider.notifier)
            .refreshOnAppResume();

        final txNotifier =
            container.read(transactionProvider.notifier)
                as SpyTransactionNotifier;
        expect(txNotifier.addedTransactions.length, 1);
        expect(txNotifier.addedTransactions.first.amount, 150);

        final state = container.read(subscriptionProvider).value!;
        // Дата посунулась у майбутнє -> платіж більше не прострочений.
        expect(
          state.subscriptions.first.nextPaymentDate.isAfter(yesterday),
          true,
        );
        // І авто-підписка не потрапила в діалог ручного підтвердження.
        expect(state.dueSubscriptions, isEmpty);
      },
    );
  });

  group('SubscriptionNotifier - User Actions (Skip & Ignore)', () {
    test(
      'ignoreSubscriptionForSession: ховає підписку з dueSubscriptions до перезапуску',
      () async {
        final container = await createContainer();
        final dueSub = subBase.copyWith(nextPaymentDate: DateTime.now());
        await StorageService.saveSubscription(db, dueSub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        expect(
          container.read(subscriptionProvider).value!.dueSubscriptions.length,
          1,
        );

        notifier.ignoreSubscriptionForSession(dueSub.id);

        final state = container.read(subscriptionProvider).value!;
        expect(state.ignoredSubIds.contains(dueSub.id), true);
        expect(state.dueSubscriptions.isEmpty, true);
      },
    );

    test(
      'confirmSubscriptionPayment: створює транзакцію та прибирає з due',
      () async {
        final container = await createContainer();
        final dueSub = subBase.copyWith(nextPaymentDate: DateTime.now());
        await StorageService.saveSubscription(db, dueSub);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        final (success, _) = await notifier.confirmSubscriptionPayment(
          dueSub,
          300,
        );

        expect(success, true);

        final txNotifier =
            container.read(transactionProvider.notifier)
                as SpyTransactionNotifier;
        expect(txNotifier.addedTransactions.length, 1);
        expect(txNotifier.addedTransactions.first.title, 'Netflix');

        final state = container.read(subscriptionProvider).value!;
        expect(state.dueSubscriptions.isEmpty, true);
      },
    );
  });

  group('SubscriptionNotifier - Lifecycle', () {
    test(
      'moveToTrash та restoreFromTrash: коректно змінюють deletedAt',
      () async {
        final container = await createContainer();
        await StorageService.saveSubscription(db, subBase);

        final notifier = container.read(subscriptionProvider.notifier);
        await Future.delayed(Duration.zero);
        await notifier.loadSubscriptions();

        await notifier.moveToTrash(subBase);
        var state = container.read(subscriptionProvider).value!;
        expect(state.subscriptions.isEmpty, true);
        expect(state.deletedSubscriptions.length, 1);

        await notifier.restoreFromTrash(subBase);
        state = container.read(subscriptionProvider).value!;
        expect(state.subscriptions.length, 1);
        expect(state.deletedSubscriptions.isEmpty, true);
      },
    );
  });
}
