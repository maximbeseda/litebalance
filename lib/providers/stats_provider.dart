import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'all_providers.dart';

part 'stats_provider.g.dart';

@Riverpod(keepAlive: true)
class Stats extends _$Stats {
  Map<String, Map<String, Map<String, int>>>? _cachedTrends;
  int _lastHistoryHash = 0;

  @override
  void build() {
    // 👇 Очищаємо кеш, коли провайдер знищується (наприклад, при Logout або Reset)
    ref.onDispose(() {
      _cachedTrends = null;
      _lastHistoryHash = 0;
    });

    // Отримуємо стан з AsyncValue
    final txAsync = ref.watch(transactionProvider);
    ref.watch(categoryProvider);

    // Беремо історію, якщо вона завантажена
    final history = txAsync.value?.history ?? [];

    final int currentHash = Object.hashAll(history);
    if (_lastHistoryHash != currentHash) {
      _cachedTrends = null;
      _lastHistoryHash = currentHash;
    }
  }

  // =======================================================
  // АНАЛІТИКА ТРЕНДІВ (ДЛЯ ГРАФІКІВ)
  // =======================================================
  Map<String, Map<String, Map<String, int>>> calculateTrends() {
    if (_cachedTrends != null) return _cachedTrends!;

    // 👇 Отримуємо історію
    final txAsync = ref.read(transactionProvider);
    final history = txAsync.value?.history ?? [];

    final catState = ref.read(categoryProvider);

    final Map<String, Map<String, Map<String, int>>> trends = {};

    final sortedHistory = List<Transaction>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Створюємо набір ID рахунків для швидкої перевірки (O(1))
    final accountIds = catState.accounts.map((a) => a.id).toSet();

    for (var tx in sortedHistory) {
      final String epoch = tx.baseCurrency.isEmpty ? 'UAH' : tx.baseCurrency;
      final String monthKey =
          "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";

      trends.putIfAbsent(epoch, () => {});
      trends[epoch]!.putIfAbsent(monthKey, () => {'incomes': 0, 'expenses': 0});

      final bool fromIsAccount = accountIds.contains(tx.fromId);
      final bool toIsAccount = accountIds.contains(tx.toId);

      // 1. Витрата: з рахунку на НЕ рахунок
      if (fromIsAccount && !toIsAccount) {
        // 👇 ВИПРАВЛЕННЯ: Додали .round(), щоб уникнути помилки типу double -> int, хоча тут baseAmount вже int.
        // Залишаємо + tx.baseAmount, бо це точно int. Якщо були помилки вище, це через інші функції.
        trends[epoch]![monthKey]!['expenses'] =
            (trends[epoch]![monthKey]!['expenses'] ?? 0) + tx.baseAmount;
      }
      // 2. Дохід: з НЕ рахунку на рахунок
      if (!fromIsAccount && toIsAccount) {
        trends[epoch]![monthKey]!['incomes'] =
            (trends[epoch]![monthKey]!['incomes'] ?? 0) + tx.baseAmount;
      }
    }

    _cachedTrends = trends;
    return trends;
  }

  // =======================================================
  // АНАЛІТИКА КРУГОВОЇ ДІАГРАМИ ТА ЗАГАЛЬНИХ СУМ
  // =======================================================
  Map<String, int> calculateTotalsForMonth(DateTime month) {
    int totalExpenses = 0;
    int totalIncomes = 0;

    // 👇 Отримуємо історію
    final txAsync = ref.read(transactionProvider);
    final history = txAsync.value?.history ?? [];

    final catState = ref.read(categoryProvider);

    final monthHistory = history.where(
      (t) => t.date.year == month.year && t.date.month == month.month,
    );

    final accountIds = catState.accounts.map((a) => a.id).toSet();

    for (var tx in monthHistory) {
      final bool fromIsAccount = accountIds.contains(tx.fromId);
      final bool toIsAccount = accountIds.contains(tx.toId);

      if (fromIsAccount && !toIsAccount) {
        totalExpenses += tx.baseAmount;
      } else if (!fromIsAccount && toIsAccount) {
        totalIncomes += tx.baseAmount;
      }
    }

    return {'expenses': totalExpenses, 'incomes': totalIncomes};
  }

  Map<String, int> calculateCategoryTotalsForMonth(
    DateTime month,
    bool isExpenses, {
    bool inBaseCurrency = true,
  }) {
    final Map<String, int> totals = {};

    // 👇 Отримуємо історію
    final txAsync = ref.read(transactionProvider);
    final history = txAsync.value?.history ?? [];

    final catState = ref.read(categoryProvider);

    final monthHistory = history.where(
      (t) => t.date.year == month.year && t.date.month == month.month,
    );

    final accountIds = catState.accounts.map((a) => a.id).toSet();

    for (var tx in monthHistory) {
      final bool fromIsAccount = accountIds.contains(tx.fromId);
      final bool toIsAccount = accountIds.contains(tx.toId);

      if (isExpenses) {
        if (fromIsAccount && !toIsAccount) {
          final int value = inBaseCurrency
              ? tx.baseAmount
              : (tx.targetAmount ?? tx.amount);
          // 👇 ВИПРАВЛЕННЯ: Додано .round() про всяк випадок, хоча value вже int.
          totals[tx.toId] = ((totals[tx.toId] ?? 0) + value).round();
        }
      } else {
        if (!fromIsAccount && toIsAccount) {
          final int value = inBaseCurrency ? tx.baseAmount : tx.amount;
          totals[tx.fromId] = ((totals[tx.fromId] ?? 0) + value).round();
        }
      }
    }

    return totals;
  }
}
