import 'dart:async';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Керує проханням оцінити додаток через нативний In-App Review (Google Play /
/// App Store). Показуємо картку оцінки лише в «природний» момент — після того,
/// як користувач уже отримав цінність і навряд чи роздратується:
///
///   • додаток відкривали щонайменше [_minLaunches] разів;
///   • у базі щонайменше [_minTransactions] транзакцій;
///   • від встановлення минуло щонайменше [_minDaysSinceInstall] днів;
///   • від попереднього прохання минуло щонайменше [_minDaysBetweenRequests] днів.
///
/// Саму картку показує система (і не гарантує показ через власні квоти), тож
/// власного UI тут немає — лише логіка «коли доречно попросити».
class ReviewService {
  ReviewService._();

  static const String _kInstallDateKey = 'review_install_date';
  static const String _kLaunchCountKey = 'review_launch_count';
  static const String _kLastRequestKey = 'review_last_request';

  static const int _minLaunches = 5;
  static const int _minTransactions = 10;
  static const int _minDaysSinceInstall = 3;
  static const int _minDaysBetweenRequests = 120;

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Викликається один раз на холодному старті (з `main`). Фіксує дату першого
  /// запуску та інкрементує лічильник запусків.
  static Future<void> recordAppOpen(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (prefs.getInt(_kInstallDateKey) == null) {
      await prefs.setInt(_kInstallDateKey, now);
    }
    final launches = (prefs.getInt(_kLaunchCountKey) ?? 0) + 1;
    await prefs.setInt(_kLaunchCountKey, launches);
  }

  /// Чиста перевірка часових умов і лічильників (без звернення до платформи —
  /// зручно тестувати). Не враховує доступність In-App Review, лише «чи час».
  static bool shouldRequestReview({
    required SharedPreferences prefs,
    required int transactionCount,
    required int nowMs,
  }) {
    if (transactionCount < _minTransactions) return false;
    if ((prefs.getInt(_kLaunchCountKey) ?? 0) < _minLaunches) return false;

    final installMs = prefs.getInt(_kInstallDateKey);
    if (installMs == null) return false; // ще не зафіксовано перший запуск
    if (nowMs - installMs < _daysMs(_minDaysSinceInstall)) return false;

    final lastRequestMs = prefs.getInt(_kLastRequestKey);
    if (lastRequestMs != null &&
        nowMs - lastRequestMs < _daysMs(_minDaysBetweenRequests)) {
      return false;
    }
    return true;
  }

  /// Перевіряє всі умови і, якщо вони виконані та система підтримує In-App
  /// Review, показує картку оцінки. Помилки навмисно ковтаємо — прохання
  /// оцінити не повинно впливати на основний сценарій.
  static Future<void> maybeRequestReview({
    required SharedPreferences prefs,
    required int transactionCount,
  }) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!shouldRequestReview(
        prefs: prefs,
        transactionCount: transactionCount,
        nowMs: nowMs,
      )) {
        return;
      }

      if (!await _inAppReview.isAvailable()) return;

      // Ставимо мітку ДО показу: навіть якщо система через квоту не покаже
      // картку, ми не смикаємо користувача частіше, ніж раз на кілька місяців.
      await prefs.setInt(_kLastRequestKey, nowMs);
      await _inAppReview.requestReview();
    } catch (_) {
      // In-App Review недоступний (напр. пристрій без сервісів Google) — тихо
      // ігноруємо.
    }
  }

  static int _daysMs(int days) => days * 24 * 60 * 60 * 1000;
}
