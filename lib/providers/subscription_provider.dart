import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import 'all_providers.dart';

part 'subscription_provider.g.dart';

class SubscriptionState {
  final List<Subscription> subscriptions;
  final List<Subscription> dueSubscriptions;
  final List<Subscription> deletedSubscriptions;
  final Set<String> ignoredSubIds;

  SubscriptionState({
    required this.subscriptions,
    required this.dueSubscriptions,
    required this.deletedSubscriptions,
    required this.ignoredSubIds,
  });

  SubscriptionState copyWith({
    List<Subscription>? subscriptions,
    List<Subscription>? dueSubscriptions,
    List<Subscription>? deletedSubscriptions,
    Set<String>? ignoredSubIds,
  }) {
    return SubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      dueSubscriptions: dueSubscriptions ?? this.dueSubscriptions,
      deletedSubscriptions: deletedSubscriptions ?? this.deletedSubscriptions,
      ignoredSubIds: ignoredSubIds ?? this.ignoredSubIds,
    );
  }

  bool get hasPendingPayments {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return subscriptions.any((sub) {
      final DateTime pDate = DateTime(
        sub.nextPaymentDate.year,
        sub.nextPaymentDate.month,
        sub.nextPaymentDate.day,
      );
      return pDate.isBefore(today) || pDate.isAtSameMomentAs(today);
    });
  }
}

@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  // Зручний геттер для доступу до нестатичного StorageService
  StorageService get _storage =>
      StorageService(ref.read(sharedPreferencesProvider));

  @override
  Future<SubscriptionState> build() async {
    // 👇 ЗАХИСТ ВІД КРЕШУ: Якщо база у цей момент перезаписується — не чіпаємо її файл
    if (ref.read(syncControllerProvider).isSyncing) {
      return SubscriptionState(
        subscriptions: [],
        dueSubscriptions: [],
        deletedSubscriptions: [],
        ignoredSubIds: {},
      );
    }

    final db = ref.read(appDatabaseProvider);
    final allSubs = await StorageService.getSubscriptions(db);

    final ignored = _storage.getIgnoredSubscriptions().toSet();

    final activeSubs = allSubs.where((s) => s.deletedAt == null).toList();
    final deletedSubs = allSubs.where((s) => s.deletedAt != null).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = activeSubs.where((sub) {
      if (ignored.contains(sub.id)) return false;
      // Авто-підписки ніколи не показуємо в діалозі ручного підтвердження —
      // їх тихо обробляє processAutoPayments(). Інакше через гонку (build викликає
      // processAutoPayments через unawaited) діалог встигає блимнути до автосписання.
      if (sub.isAutoPay) return false;
      final pDate = DateTime(
        sub.nextPaymentDate.year,
        sub.nextPaymentDate.month,
        sub.nextPaymentDate.day,
      );
      return pDate.isBefore(today) || pDate.isAtSameMomentAs(today);
    }).toList();

    final initialState = SubscriptionState(
      subscriptions: activeSubs,
      dueSubscriptions: due,
      deletedSubscriptions: deletedSubs,
      ignoredSubIds: ignored,
    );

    unawaited(processAutoPayments());

    return initialState;
  }

  void _updateState(SubscriptionState Function(SubscriptionState) update) {
    if (state is AsyncData) {
      state = AsyncData(update(state.value!));
    }
  }

  Future<void> loadSubscriptions() async {
    // 👇 ЗАХИСТ ВІД КРЕШУ: Не ліземо в базу, якщо файл SQLite зараз закривається/копіюється
    if (ref.read(syncControllerProvider).isSyncing) return;

    final db = ref.read(appDatabaseProvider);
    final allSubs = await StorageService.getSubscriptions(db);

    final ignored = _storage.getIgnoredSubscriptions().toSet();

    final activeSubs = allSubs.where((s) => s.deletedAt == null).toList();
    final deletedSubs = allSubs.where((s) => s.deletedAt != null).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = activeSubs.where((sub) {
      if (ignored.contains(sub.id)) return false;
      // Авто-підписки ніколи не показуємо в діалозі ручного підтвердження —
      // їх тихо обробляє processAutoPayments(). Інакше через гонку (build викликає
      // processAutoPayments через unawaited) діалог встигає блимнути до автосписання.
      if (sub.isAutoPay) return false;
      final pDate = DateTime(
        sub.nextPaymentDate.year,
        sub.nextPaymentDate.month,
        sub.nextPaymentDate.day,
      );
      return pDate.isBefore(today) || pDate.isAtSameMomentAs(today);
    }).toList();

    _updateState(
      (s) => s.copyWith(
        subscriptions: activeSubs,
        deletedSubscriptions: deletedSubs,
        ignoredSubIds: ignored,
        dueSubscriptions: due,
      ),
    );

    await processAutoPayments();
  }

  void _checkDueSubscriptions() {
    _updateState((s) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final due = s.subscriptions.where((sub) {
        if (s.ignoredSubIds.contains(sub.id)) return false;
        // Авто-підписки не потрапляють у діалог ручного підтвердження.
        if (sub.isAutoPay) return false;
        final paymentDate = DateTime(
          sub.nextPaymentDate.year,
          sub.nextPaymentDate.month,
          sub.nextPaymentDate.day,
        );
        return paymentDate.isBefore(today) ||
            paymentDate.isAtSameMomentAs(today);
      }).toList();

      return s.copyWith(dueSubscriptions: due);
    });
  }

  Future<void> addSubscription(Subscription sub) async {
    final db = ref.read(appDatabaseProvider);
    _updateState(
      (s) => s.copyWith(
        subscriptions: List<Subscription>.from(s.subscriptions)..add(sub),
      ),
    );

    await StorageService.saveSubscription(db, sub);

    // 👇 ДОДАНО: Прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await processAutoPayments();
    _checkDueSubscriptions();
  }

  Future<void> updateSubscription(Subscription updatedSub) async {
    final db = ref.read(appDatabaseProvider);
    _updateState((s) {
      final newSubs = List<Subscription>.from(s.subscriptions);
      final int index = newSubs.indexWhere((item) => item.id == updatedSub.id);
      if (index != -1) {
        newSubs[index] = updatedSub;
      }
      return s.copyWith(subscriptions: newSubs);
    });

    await StorageService.saveSubscription(db, updatedSub);

    // 👇 ДОДАНО: Прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await processAutoPayments();
    _checkDueSubscriptions();
  }

  Future<void> moveToTrash(Subscription sub) async {
    final db = ref.read(appDatabaseProvider);
    final deletedSub = sub.copyWith(deletedAt: drift.Value(DateTime.now()));
    await StorageService.saveSubscription(db, deletedSub);

    // 👇 ДОДАНО: Прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadSubscriptions();
  }

  Future<void> restoreFromTrash(Subscription sub) async {
    final db = ref.read(appDatabaseProvider);
    final restoredSub = sub.copyWith(deletedAt: const drift.Value(null));
    await StorageService.saveSubscription(db, restoredSub);

    // 👇 ДОДАНО: Прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadSubscriptions();
  }

  Future<void> deletePermanently(String id) async {
    final db = ref.read(appDatabaseProvider);
    await StorageService.deleteSubscription(db, id);

    // 👇 ДОДАНО: Прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadSubscriptions();
  }

  Future<(bool, String)> confirmSubscriptionPayment(
    Subscription sub,
    int finalAmount,
  ) async {
    if (state is! AsyncData) return (false, 'loading'.tr());
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    final catState = ref.read(categoryProvider);
    final txNotifier = ref.read(transactionProvider.notifier);
    final settingsState = ref.read(settingsProvider);

    final all = catState.allCategoriesList;
    final sourceAccount = all.firstWhereOrNull((c) => c.id == sub.accountId);
    final targetExpense = all.firstWhereOrNull((c) => c.id == sub.categoryId);

    if (sourceAccount == null || targetExpense == null) {
      return (false, 'error_category_not_found'.tr());
    }

    if (sourceAccount.isArchived || targetExpense.isArchived) {
      return (false, 'error_category_deleted'.tr());
    }

    _updateState(
      (s) => s.copyWith(
        dueSubscriptions: List<Subscription>.from(s.dueSubscriptions)
          ..removeWhere((item) => item.id == sub.id),
      ),
    );

    final double subRate = settingsState.exchangeRates[sub.currency] ?? 1.0;
    double accRate = settingsState.exchangeRates[sourceAccount.currency] ?? 1.0;
    double expRate = settingsState.exchangeRates[targetExpense.currency] ?? 1.0;

    if (accRate == 0) accRate = 1.0;
    if (expRate == 0) expRate = 1.0;

    int accountDeduction = finalAmount;
    if (sourceAccount.currency != sub.currency) {
      accountDeduction = (finalAmount * (accRate / subRate)).round();
    }

    int expenseAddition = finalAmount;
    if (targetExpense.currency != sub.currency) {
      expenseAddition = (finalAmount * (expRate / subRate)).round();
    }

    if (sourceAccount.amount < accountDeduction) {
      _checkDueSubscriptions();
      return (false, 'not_enough_funds'.tr(args: [sourceAccount.name]));
    }

    final bool isMultiCurrency =
        sourceAccount.currency != targetExpense.currency;

    final newTx = Transaction(
      id: const Uuid().v4(),
      fromId: sourceAccount.id,
      toId: targetExpense.id,
      title: sub.name,
      amount: accountDeduction,
      date: sub.nextPaymentDate,
      currency: sourceAccount.currency,
      targetAmount: isMultiCurrency ? expenseAddition : null,
      targetCurrency: isMultiCurrency ? targetExpense.currency : null,
      baseAmount: 0,
      baseCurrency: '',
    );

    await txNotifier.addTransactionDirectly(newTx);
    await SubscriptionService.advanceOnePeriod(db, sub);

    // 👇 ДОДАНО: Прапорець бекапу (хоча транзакція його вже ставить, це для надійності)
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    final newIgnored = Set<String>.from(currentState.ignoredSubIds)
      ..remove(sub.id);
    _updateState((s) => s.copyWith(ignoredSubIds: newIgnored));

    await _storage.saveIgnoredSubscriptions(newIgnored.toList());

    await loadSubscriptions();
    return (true, 'paid_success'.tr(args: [sub.name]));
  }

  Future<void> ignoreSubscriptionPermanently(String subId) async {
    Set<String>? nextIgnored;
    _updateState((s) {
      nextIgnored = Set<String>.from(s.ignoredSubIds)..add(subId);
      return s.copyWith(ignoredSubIds: nextIgnored!);
    });

    if (nextIgnored != null) {
      await _storage.saveIgnoredSubscriptions(nextIgnored!.toList());
    }
    _checkDueSubscriptions();
  }

  Future<void> refreshOnAppResume() async {
    await processAutoPayments();
    _checkDueSubscriptions();
  }

  Future<void> processAutoPayments() async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    final catState = ref.read(categoryProvider);
    final txNotifier = ref.read(transactionProvider.notifier);
    final settingsState = ref.read(settingsProvider);

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    bool processedAny = false;

    final List<Transaction> pendingTransactions = [];
    final List<Subscription> updatedSubsList = [];

    for (var sub in currentState.subscriptions) {
      if (!sub.isAutoPay) continue;

      final all = catState.allCategoriesList;
      final account = all.where((c) => c.id == sub.accountId).firstOrNull;
      final expense = all.where((c) => c.id == sub.categoryId).firstOrNull;

      if (account == null ||
          expense == null ||
          account.isArchived ||
          expense.isArchived) {
        continue;
      }

      final double subRate = settingsState.exchangeRates[sub.currency] ?? 1.0;
      double accRate = settingsState.exchangeRates[account.currency] ?? 1.0;
      double expRate = settingsState.exchangeRates[expense.currency] ?? 1.0;

      if (accRate == 0) accRate = 1.0;
      if (expRate == 0) expRate = 1.0;

      int accountDeduction = sub.amount;
      if (account.currency != sub.currency) {
        accountDeduction = (sub.amount * (accRate / subRate)).round();
      }

      int expenseAddition = sub.amount;
      if (expense.currency != sub.currency) {
        expenseAddition = (sub.amount * (expRate / subRate)).round();
      }

      final bool isMultiCurrency = account.currency != expense.currency;
      int currentBalance = account.amount;
      bool subUpdated = false;
      var currentSub = sub;

      while (true) {
        final DateTime pDate = DateTime(
          currentSub.nextPaymentDate.year,
          currentSub.nextPaymentDate.month,
          currentSub.nextPaymentDate.day,
        );

        if (pDate.isAfter(today)) break;

        if (currentBalance >= accountDeduction) {
          final newTx = Transaction(
            id: const Uuid().v4(),
            fromId: account.id,
            toId: expense.id,
            title: 'auto_payment_marker'.tr(args: [currentSub.name]),
            amount: accountDeduction,
            date: currentSub.nextPaymentDate,
            currency: account.currency,
            targetAmount: isMultiCurrency ? expenseAddition : null,
            targetCurrency: isMultiCurrency ? expense.currency : null,
            baseAmount: 0,
            baseCurrency: '',
          );

          pendingTransactions.add(newTx);
          currentBalance -= accountDeduction;

          if (currentSub.periodicity == 'monthly') {
            final int nextMonth = pDate.month == 12 ? 1 : pDate.month + 1;
            final int nextYear = pDate.month == 12
                ? pDate.year + 1
                : pDate.year;
            int nextDay = currentSub.nextPaymentDate.day;
            final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
            if (nextDay > lastDayOfNextMonth) nextDay = lastDayOfNextMonth;
            currentSub = currentSub.copyWith(
              nextPaymentDate: DateTime(nextYear, nextMonth, nextDay),
            );
          } else if (currentSub.periodicity == 'yearly') {
            currentSub = currentSub.copyWith(
              nextPaymentDate: DateTime(pDate.year + 1, pDate.month, pDate.day),
            );
          } else if (currentSub.periodicity == 'weekly') {
            currentSub = currentSub.copyWith(
              nextPaymentDate: pDate.add(const Duration(days: 7)),
            );
          } else if (currentSub.periodicity == 'every_28_days') {
            currentSub = currentSub.copyWith(
              nextPaymentDate: pDate.add(const Duration(days: 28)),
            );
          } else if (currentSub.periodicity == 'every_30_days') {
            currentSub = currentSub.copyWith(
              nextPaymentDate: pDate.add(const Duration(days: 30)),
            );
          }

          subUpdated = true;
          processedAny = true;
        } else {
          break;
        }
      }

      if (subUpdated) {
        updatedSubsList.add(currentSub);
        await StorageService.saveSubscription(db, currentSub);
      }
    }

    for (var tx in pendingTransactions) {
      await txNotifier.addTransactionDirectly(tx);
    }

    if (processedAny) {
      _updateState((s) {
        final newSubs = List<Subscription>.from(s.subscriptions);
        for (var us in updatedSubsList) {
          final int index = newSubs.indexWhere((item) => item.id == us.id);
          if (index != -1) newSubs[index] = us;
        }
        return s.copyWith(subscriptions: newSubs);
      });

      // 👇 ДОДАНО: Якщо пройшли автосписання, ставимо прапорець бекапу
      ref.read(dbDirtyProvider.notifier).setDirty(true);

      _checkDueSubscriptions();
    }
  }

  Future<void> skipSubscriptionPayment(Subscription sub) async {
    _updateState(
      (s) => s.copyWith(
        dueSubscriptions: List<Subscription>.from(s.dueSubscriptions)
          ..removeWhere((item) => item.id == sub.id),
      ),
    );

    final db = ref.read(appDatabaseProvider);
    await SubscriptionService.advanceOnePeriod(db, sub);

    // 👇 ДОДАНО: Прапорець бекапу (бо дата підписки оновилася в базі)
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadSubscriptions();
  }

  void ignoreSubscriptionForSession(String subId) {
    _updateState((s) {
      final newIgnored = Set<String>.from(s.ignoredSubIds)..add(subId);
      return s.copyWith(ignoredSubIds: newIgnored);
    });
    _checkDueSubscriptions();
  }

  Future<void> clearAllSubscriptions() async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);

    for (var sub in [
      ...currentState.subscriptions,
      ...currentState.deletedSubscriptions,
    ]) {
      await StorageService.deleteSubscription(db, sub.id);
    }

    await _storage.saveIgnoredSubscriptions([]);

    // 👇 ДОДАНО: Прапорець бекапу (видалили все)
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    _updateState(
      (s) => s.copyWith(
        subscriptions: [],
        dueSubscriptions: [],
        deletedSubscriptions: [],
        ignoredSubIds: {},
      ),
    );
  }
}
