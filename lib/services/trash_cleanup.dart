import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/all_providers.dart';

/// Проактивне очищення кошика: остаточно видаляє елементи (категорії,
/// транзакції, підписки), що пролежали в кошику ≥30 днів.
///
/// Раніше ця логіка жила лише в `initState` екрана кошика, тож прострочене
/// видалялося тільки при його відкритті — а червоний лічильник у меню «зависав».
/// Тепер її можна запускати проактивно (на поверненні з фону, при відкритті меню).
class TrashCleanup {
  TrashCleanup._();

  static const int _retentionDays = 30;

  // Захист від конкурентних запусків (напр. resume + відкриття меню водночас).
  static bool _running = false;

  /// Зручний виклик із віджета.
  static Future<bool> runFor(WidgetRef ref) => run(
    categoryState: ref.read(categoryProvider),
    categoryNotifier: ref.read(categoryProvider.notifier),
    transactionState: ref.read(transactionProvider).value,
    transactionNotifier: ref.read(transactionProvider.notifier),
    subscriptionState: ref.read(subscriptionProvider).value,
    subscriptionNotifier: ref.read(subscriptionProvider.notifier),
  );

  /// Чиста логіка (явні залежності — легко тестувати).
  /// Повертає true, якщо щось було видалено.
  static Future<bool> run({
    required CategoryState categoryState,
    required CategoryNotifier categoryNotifier,
    required TransactionState? transactionState,
    required TransactionNotifier transactionNotifier,
    required SubscriptionState? subscriptionState,
    required SubscriptionNotifier subscriptionNotifier,
  }) async {
    if (_running) return false;
    _running = true;
    try {
      final now = DateTime.now();
      bool changed = false;

      bool expired(DateTime? deletedAt) =>
          deletedAt != null &&
          now.difference(deletedAt).inDays >= _retentionDays;

      // Ітеруємо знімки списків (immutable), тож мутації провайдерів під час
      // циклу безпечні.
      for (final cat in categoryState.deletedCategories) {
        if (expired(cat.deletedAt)) {
          await categoryNotifier.emptyTrashOrArchive(cat);
          changed = true;
        }
      }

      if (transactionState != null) {
        for (final tx in transactionState.deletedHistory) {
          if (expired(tx.deletedAt)) {
            await transactionNotifier.deletePermanently(tx);
            changed = true;
          }
        }
      }

      if (subscriptionState != null) {
        for (final sub in subscriptionState.deletedSubscriptions) {
          if (expired(sub.deletedAt)) {
            await subscriptionNotifier.deletePermanently(sub.id);
            changed = true;
          }
        }
      }

      return changed;
    } finally {
      _running = false;
    }
  }
}
