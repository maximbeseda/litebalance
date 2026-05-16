import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/storage_service.dart';
import 'all_providers.dart';

part 'transaction_provider.g.dart';

// 1. СТАН (State)
class TransactionState {
  final List<Transaction> history;
  final List<Transaction> deletedHistory;
  final DateTime selectedMonth;
  final bool isMigrating;
  final String? lastKnownBaseCurrency;

  TransactionState({
    required this.history,
    required this.deletedHistory,
    required this.selectedMonth,
    required this.isMigrating,
    this.lastKnownBaseCurrency,
  });

  TransactionState copyWith({
    List<Transaction>? history,
    List<Transaction>? deletedHistory,
    DateTime? selectedMonth,
    bool? isMigrating,
    String? lastKnownBaseCurrency,
  }) {
    return TransactionState(
      history: history ?? this.history,
      deletedHistory: deletedHistory ?? this.deletedHistory,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isMigrating: isMigrating ?? this.isMigrating,
      lastKnownBaseCurrency:
          lastKnownBaseCurrency ?? this.lastKnownBaseCurrency,
    );
  }

  bool get isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }
}

// 2. СУЧАСНИЙ АСИНХРОННИЙ NOTIFIER
@Riverpod(keepAlive: true)
class TransactionNotifier extends _$TransactionNotifier {
  @override
  Future<TransactionState> build() async {
    // 👇 ЗАХИСТ ВІД КРЕШУ: Якщо база підміняється прямо зараз — повертаємо дефолтний стан і не чіпаємо файл
    if (ref.read(syncControllerProvider).isSyncing) {
      return TransactionState(
        history: [],
        deletedHistory: [],
        selectedMonth: DateTime(DateTime.now().year, DateTime.now().month, 1),
        isMigrating: false,
      );
    }

    ref.listen<String>(settingsProvider.select((s) => s.baseCurrency), (
      previous,
      next,
    ) {
      if (previous != null && previous != next) {
        _migrateCurrentMonthBaseCurrency(next);
      }
    });

    final db = ref.read(appDatabaseProvider);
    final loadedHistory = await StorageService.loadHistory(db);
    loadedHistory.sort((a, b) => b.date.compareTo(a.date));

    final activeHistory = loadedHistory
        .where((t) => t.deletedAt == null)
        .toList();
    final deletedHistory = loadedHistory
        .where((t) => t.deletedAt != null)
        .toList();

    final initialState = TransactionState(
      history: activeHistory,
      deletedHistory: deletedHistory,
      selectedMonth: DateTime(DateTime.now().year, DateTime.now().month, 1),
      isMigrating: false,
    );

    // Міграція валюти (якщо потрібно)
    final currentBase = ref.read(settingsProvider).baseCurrency;
    final now = DateTime.now();
    final currentMonthTxs = activeHistory
        .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
        .toList();

    if (currentMonthTxs.isNotEmpty &&
        currentMonthTxs.first.baseCurrency != currentBase) {
      unawaited(_migrateCurrentMonthBaseCurrency(currentBase));
    }

    return initialState;
  }

  // Хелпер для безпечного оновлення стану
  void _updateState(TransactionState Function(TransactionState) update) {
    if (state is AsyncData) {
      state = AsyncData(update(state.value!));
    }
  }

  Future<void> loadHistory() async {
    // 👇 ЗАХИСТ ВІД КРЕШУ: Не ліземо в базу, якщо файл SQLite у цей момент закривається/копіюється
    if (ref.read(syncControllerProvider).isSyncing) return;

    final db = ref.read(appDatabaseProvider);
    final loadedHistory = await StorageService.loadHistory(db);
    loadedHistory.sort((a, b) => b.date.compareTo(a.date));

    final activeHistory = loadedHistory
        .where((t) => t.deletedAt == null)
        .toList();
    final deletedHistory = loadedHistory
        .where((t) => t.deletedAt != null)
        .toList();

    _updateState(
      (s) => s.copyWith(history: activeHistory, deletedHistory: deletedHistory),
    );
  }

  void changeMonth(int offset) {
    _updateState(
      (s) => s.copyWith(
        selectedMonth: DateTime(
          s.selectedMonth.year,
          s.selectedMonth.month + offset,
          1,
        ),
      ),
    );
  }

  void setMonth(DateTime newMonth) {
    _updateState(
      (s) =>
          s.copyWith(selectedMonth: DateTime(newMonth.year, newMonth.month, 1)),
    );
  }

  Future<int> _calculateBaseAmountAsync(
    int amount,
    String currency,
    int? targetAmount,
    String? targetCurrency,
    String baseCur,
    DateTime txDate,
  ) async {
    if (currency == baseCur) return amount;
    if (targetCurrency == baseCur && targetAmount != null) return targetAmount;

    final settingsNotif = ref.read(settingsProvider.notifier);
    double fromRate =
        (await settingsNotif.getRateForDate(currency, txDate)) ?? 1.0;
    final double toRate =
        (await settingsNotif.getRateForDate(baseCur, txDate)) ?? 1.0;

    if (fromRate == 0) fromRate = 1.0;
    return (amount * (toRate / fromRate)).round();
  }

  void _updateAccountBalance(String categoryId, int delta) {
    final catState = ref.read(categoryProvider);
    final catNotifier = ref.read(categoryProvider.notifier);

    final category = catState.allCategoriesList
        .where((c) => c.id == categoryId)
        .firstOrNull;
    if (category != null && category.type == CategoryType.account) {
      catNotifier.updateCategoryAmount(categoryId, delta);
    }
  }

  Future<void> addTransactionDirectly(Transaction tx) async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    final currentBase = ref.read(settingsProvider).baseCurrency;

    int baseAmt;
    if (tx.baseCurrency == currentBase && tx.baseAmount != 0) {
      baseAmt = tx.baseAmount;
    } else {
      baseAmt = await _calculateBaseAmountAsync(
        tx.amount,
        tx.currency,
        tx.targetAmount,
        tx.targetCurrency,
        currentBase,
        tx.date,
      );
    }

    final updatedTx = tx.copyWith(
      baseCurrency: currentBase,
      baseAmount: baseAmt,
      titleLower: drift.Value(tx.title.toLowerCase()),
    );

    final newHistory = List<Transaction>.from(currentState.history)
      ..add(updatedTx);
    newHistory.sort((a, b) => b.date.compareTo(a.date));

    _updateState((s) => s.copyWith(history: newHistory));
    await StorageService.saveTransaction(db, updatedTx);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    _updateAccountBalance(updatedTx.fromId, -updatedTx.amount);
    _updateAccountBalance(
      updatedTx.toId,
      updatedTx.targetAmount ?? updatedTx.amount,
    );
  }

  Future<void> addTransfer(
    Category source,
    Category target,
    int amount,
    DateTime date, {
    int? targetAmount,
  }) async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    final catNotifier = ref.read(categoryProvider.notifier);

    if (source.type == CategoryType.account) {
      catNotifier.updateCategoryAmount(source.id, -amount);
    }
    if (target.type == CategoryType.account) {
      catNotifier.updateCategoryAmount(target.id, targetAmount ?? amount);
    }

    final currentBase = ref.read(settingsProvider).baseCurrency;
    final baseAmt = await _calculateBaseAmountAsync(
      amount,
      source.currency,
      targetAmount,
      targetAmount != null ? target.currency : null,
      currentBase,
      date,
    );

    final newTx = Transaction(
      id: const Uuid().v4(),
      fromId: source.id,
      toId: target.id,
      title: target.name,
      titleLower: target.name.toLowerCase(),
      amount: amount,
      date: date,
      currency: source.currency,
      targetAmount: targetAmount,
      targetCurrency: targetAmount != null ? target.currency : null,
      baseAmount: baseAmt,
      baseCurrency: currentBase,
    );

    final newHistory = List<Transaction>.from(currentState.history)
      ..insert(0, newTx);

    _updateState((s) => s.copyWith(history: newHistory));
    await StorageService.saveTransaction(db, newTx);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }

  Future<void> editTransaction(
    Transaction oldT,
    int newAmount,
    DateTime newDate, {
    int? newTargetAmount,
  }) async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    _updateAccountBalance(oldT.fromId, oldT.amount);
    _updateAccountBalance(oldT.toId, -(oldT.targetAmount ?? oldT.amount));

    final int previousAmount = oldT.amount;
    int finalTargetAmount;
    if (newTargetAmount != null) {
      finalTargetAmount = newTargetAmount;
    } else if (oldT.targetAmount != null && previousAmount > 0) {
      finalTargetAmount = (oldT.targetAmount! * (newAmount / previousAmount))
          .round();
    } else {
      finalTargetAmount = newAmount;
    }

    int finalBaseAmount;
    if (previousAmount > 0) {
      finalBaseAmount = (oldT.baseAmount * (newAmount / previousAmount))
          .round();
    } else {
      finalBaseAmount = await _calculateBaseAmountAsync(
        newAmount,
        oldT.currency,
        finalTargetAmount,
        oldT.targetCurrency,
        oldT.baseCurrency,
        newDate,
      );
    }

    final updatedT = oldT.copyWith(
      amount: newAmount,
      date: newDate,
      targetAmount: drift.Value(finalTargetAmount),
      baseAmount: finalBaseAmount,
      titleLower: drift.Value(oldT.title.toLowerCase()),
    );

    _updateAccountBalance(updatedT.fromId, -updatedT.amount);
    _updateAccountBalance(
      updatedT.toId,
      updatedT.targetAmount ?? updatedT.amount,
    );

    final newHistory = List<Transaction>.from(currentState.history);
    final int index = newHistory.indexWhere((t) => t.id == oldT.id);
    if (index != -1) newHistory[index] = updatedT;
    newHistory.sort((a, b) => b.date.compareTo(a.date));

    _updateState((s) => s.copyWith(history: newHistory));
    await StorageService.saveTransaction(db, updatedT);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }

  Future<void> moveToTrash(Transaction t) async {
    final db = ref.read(appDatabaseProvider);
    _updateAccountBalance(t.fromId, t.amount);
    _updateAccountBalance(t.toId, -(t.targetAmount ?? t.amount));

    final trashedT = t.copyWith(deletedAt: drift.Value(DateTime.now()));
    await StorageService.saveTransaction(db, trashedT);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadHistory();
  }

  Future<void> restoreFromTrash(Transaction t) async {
    final db = ref.read(appDatabaseProvider);
    _updateAccountBalance(t.fromId, -t.amount);
    _updateAccountBalance(t.toId, (t.targetAmount ?? t.amount));

    final restoredT = t.copyWith(deletedAt: const drift.Value(null));
    await StorageService.saveTransaction(db, restoredT);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadHistory();
  }

  Future<void> deletePermanently(Transaction t) async {
    final db = ref.read(appDatabaseProvider);
    await StorageService.removeTransaction(db, t.id);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadHistory();
  }

  Future<void> _migrateCurrentMonthBaseCurrency(String newBase) async {
    if (state is! AsyncData) return;
    final currentState = state.value!;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final newHistory = List<Transaction>.from(currentState.history);

    final currentMonthTxs = newHistory
        .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
        .toList();

    if (currentMonthTxs.isEmpty) {
      _updateState((s) => s.copyWith(lastKnownBaseCurrency: newBase));
      return;
    }

    _updateState(
      (s) => s.copyWith(isMigrating: true, lastKnownBaseCurrency: newBase),
    );

    bool wasChanged = false;

    for (int i = 0; i < currentMonthTxs.length; i++) {
      var tx = currentMonthTxs[i];

      final int newBaseAmount = await _calculateBaseAmountAsync(
        tx.amount,
        tx.currency,
        tx.targetAmount,
        tx.targetCurrency,
        newBase,
        tx.date,
      );

      if (tx.baseAmount == newBaseAmount && tx.baseCurrency == newBase) {
        continue;
      }

      tx = tx.copyWith(baseAmount: newBaseAmount, baseCurrency: newBase);

      final int mainIndex = newHistory.indexWhere((t) => t.id == tx.id);
      if (mainIndex != -1) newHistory[mainIndex] = tx;

      await StorageService.saveTransaction(db, tx);
      wasChanged = true;
    }

    // 👇 ДОДАНО: Якщо хоча б одна транзакція змінилась — ставимо прапорець
    if (wasChanged) {
      ref.read(dbDirtyProvider.notifier).setDirty(true);
    }

    _updateState((s) => s.copyWith(history: newHistory, isMigrating: false));
  }

  Future<void> clearAllTransactions() async {
    final db = ref.read(appDatabaseProvider);
    _updateState((s) => s.copyWith(history: [], deletedHistory: []));
    await StorageService.deleteAllTransactions(db);

    // 👇 ДОДАНО: Ставимо прапорець бекапу (бо база очистилась)
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }
}
