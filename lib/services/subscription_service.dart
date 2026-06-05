import '../database/app_database.dart';
import 'storage_service.dart';

class SubscriptionService {
  /// Винесли сюди складну логіку перенесення дати (наприклад, після довгої паузи)
  /// 👇 ТЕПЕР ПРИЙМАЄ [db] ЯК ПЕРШИЙ ПАРАМЕТР
  static Future<void> shiftSubscriptionDate(
    AppDatabase db,
    Subscription sub, {
    DateTime? todayOverride, // для тестів
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day); // 00:00:00

    DateTime nextDate = DateTime(
      sub.nextPaymentDate.year,
      sub.nextPaymentDate.month,
      sub.nextPaymentDate.day,
    );

    while (nextDate.isBefore(today) || nextDate.isAtSameMomentAs(today)) {
      if (sub.periodicity == 'monthly') {
        final int nextMonth = nextDate.month == 12 ? 1 : nextDate.month + 1;
        final int nextYear = nextDate.month == 12 ? nextDate.year + 1 : nextDate.year;

        int nextDay = sub.nextPaymentDate.day;
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (nextDay > lastDayOfNextMonth) nextDay = lastDayOfNextMonth;

        nextDate = DateTime(nextYear, nextMonth, nextDay);
      } else if (sub.periodicity == 'yearly') {
        nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
      } else if (sub.periodicity == 'weekly') {
        nextDate = nextDate.add(const Duration(days: 7));
      } else if (sub.periodicity == 'every_28_days') {
        nextDate = nextDate.add(const Duration(days: 28));
      } else if (sub.periodicity == 'every_30_days') {
        nextDate = nextDate.add(const Duration(days: 30));
      }
    }

    final updatedSub = sub.copyWith(nextPaymentDate: nextDate);
    // 👇 Передаємо db для збереження
    await StorageService.saveSubscription(db, updatedSub);
  }

  /// Метод для зсуву дати рівно на 1 період вперед (для покрокової автооплати)
  /// 👇 ТЕПЕР ПРИЙМАЄ [db] ЯК ПЕРШИЙ ПАРАМЕТР
  static Future<void> advanceOnePeriod(AppDatabase db, Subscription sub) async {
    DateTime nextDate = sub.nextPaymentDate;

    if (sub.periodicity == 'monthly') {
      final int nextMonth = nextDate.month == 12 ? 1 : nextDate.month + 1;
      final int nextYear = nextDate.month == 12 ? nextDate.year + 1 : nextDate.year;

      int nextDay = sub.nextPaymentDate.day;
      final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      if (nextDay > lastDayOfNextMonth) nextDay = lastDayOfNextMonth;

      nextDate = DateTime(nextYear, nextMonth, nextDay);
    } else if (sub.periodicity == 'yearly') {
      nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
    } else if (sub.periodicity == 'weekly') {
      nextDate = nextDate.add(const Duration(days: 7));
    } else if (sub.periodicity == 'every_28_days') {
      nextDate = nextDate.add(const Duration(days: 28));
    } else if (sub.periodicity == 'every_30_days') {
      nextDate = nextDate.add(const Duration(days: 30));
    }

    final updatedSub = sub.copyWith(nextPaymentDate: nextDate);
    // 👇 Передаємо db для збереження
    await StorageService.saveSubscription(db, updatedSub);
  }
}
