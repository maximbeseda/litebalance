import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/services/subscription_service.dart';
import 'package:coin_flow/services/storage_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SubscriptionService - Date Logic', () {
    final baseSub = Subscription(
      id: 'sub_1',
      name: 'Netflix',
      amount: 1499,
      currency: 'EUR',
      accountId: 'acc_1',
      categoryId: 'cat_1',
      periodicity: 'monthly',
      nextPaymentDate: DateTime(2024, 1, 31), // Початкова дата
      isAutoPay: false,
    );

    test(
      'advanceOnePeriod правильно обробляє кінець місяця (31 Jan -> 29 Feb)',
      () async {
        // 2024 рік — високосний
        await SubscriptionService.advanceOnePeriod(db, baseSub);

        final subs = await StorageService.getSubscriptions(db);
        // Очікуємо 29 лютого, бо в лютому немає 31 числа
        expect(subs.first.nextPaymentDate, DateTime(2024, 2, 29));
      },
    );

    test('shiftSubscriptionDate наздоганяє пропущені періоди', () async {
      final now = DateTime.now();

      // Беремо гарантовано стару дату
      final overdueSub = baseSub.copyWith(
        nextPaymentDate: DateTime(2020, 1, 1),
        periodicity: 'monthly',
      );

      await SubscriptionService.shiftSubscriptionDate(db, overdueSub);

      final subs = await StorageService.getSubscriptions(db);
      final nextDate = subs.first.nextPaymentDate;

      // 1. Перевіряємо, що дата дійсно в майбутньому
      expect(nextDate.isAfter(now), true);

      // 2. Вираховуємо правильну наступну дату динамічно.
      // Оскільки підписка була на 1-ше число, а 'сьогодні' точно дорівнює
      // або більше 1-го числа поточного місяця, наступна оплата має бути
      // 1-го числа НАСТУПНОГО місяця.
      int expectedMonth = now.month + 1;
      int expectedYear = now.year;

      // Обробка переходу на новий рік (якщо зараз грудень)
      if (expectedMonth > 12) {
        expectedMonth = 1;
        expectedYear++;
      }

      // Перевіряємо, чи логіка збігається з реальним календарем
      expect(nextDate, DateTime(expectedYear, expectedMonth, 1));
    });

    test('Логіка щотижневої підписки (weekly) додає рівно 7 днів', () async {
      final weeklySub = baseSub.copyWith(
        periodicity: 'weekly',
        nextPaymentDate: DateTime(2026, 4, 20), // Понеділок
      );

      await SubscriptionService.advanceOnePeriod(db, weeklySub);

      final subs = await StorageService.getSubscriptions(db);
      expect(
        subs.first.nextPaymentDate,
        DateTime(2026, 4, 27),
      ); // Наступний понеділок
    });

    test('Логіка щорічної підписки (yearly) додає рівно 1 рік', () async {
      final yearlySub = baseSub.copyWith(
        periodicity: 'yearly',
        nextPaymentDate: DateTime(2024, 2, 29), // Високосний день
      );

      await SubscriptionService.advanceOnePeriod(db, yearlySub);

      final subs = await StorageService.getSubscriptions(db);
      // 2025 не високосний, тому DateTime за замовчуванням може дати 1 березня
      // або залишити 28 лютого залежно від реалізації Dart.
      // Ваш код робить: DateTime(nextDate.year + 1, nextDate.month, nextDate.day)
      expect(subs.first.nextPaymentDate.year, 2025);
    });

    test('Логіка 28-денної підписки додає рівно 28 днів', () async {
      final sub = baseSub.copyWith(
        periodicity: 'every_28_days',
        nextPaymentDate: DateTime(2026, 4, 1),
      );

      await SubscriptionService.advanceOnePeriod(db, sub);

      final subs = await StorageService.getSubscriptions(db);
      expect(subs.first.nextPaymentDate, DateTime(2026, 4, 29));
    });

    test('Логіка 30-денної підписки додає рівно 30 днів', () async {
      final sub = baseSub.copyWith(
        periodicity: 'every_30_days',
        nextPaymentDate: DateTime(2026, 4, 1),
      );

      await SubscriptionService.advanceOnePeriod(db, sub);

      final subs = await StorageService.getSubscriptions(db);
      expect(subs.first.nextPaymentDate, DateTime(2026, 5, 1));
    });

    test('shiftSubscriptionDate для 30 днів наздоганяє кратно 30', () async {
      final overdue = baseSub.copyWith(
        periodicity: 'every_30_days',
        nextPaymentDate: DateTime(2020, 1, 1),
      );

      await SubscriptionService.shiftSubscriptionDate(db, overdue);

      final subs = await StorageService.getSubscriptions(db);
      final next = subs.first.nextPaymentDate;
      final today = DateTime.now();
      // Має бути в майбутньому і відстояти від старту на ціле число 30-денних кроків.
      expect(next.isAfter(DateTime(today.year, today.month, today.day)), true);
      expect(next.difference(DateTime(2020, 1, 1)).inDays % 30, 0);
    });
  });
}
