import 'dart:async';

/// Прапорець «довіреної взаємодії» для [AppLockGate].
///
/// Деякі системні дії всередині застосунку (вибір файлу, шит «Поділитися»,
/// вхід через Google) тимчасово згортають застосунок і інакше спричинили б
/// privacy-шторку чи екран блокування. Обгортаємо такі виклики в [runTrusted]:
/// на час їх виконання [AppLockGate] ігнорує згортання.
class AppLock {
  AppLock._();

  static int _trusted = 0;

  static bool get isTrusted => _trusted > 0;

  static void beginTrusted() => _trusted++;

  static void endTrusted() {
    if (_trusted > 0) _trusted--;
  }

  /// Виконує [action] як довірену взаємодію. Прапорець тримається ще ~1с після
  /// завершення, щоб подія `resumed` після закриття системного UI не зняла
  /// шторку передчасно й не заблокувала застосунок.
  static Future<T> runTrusted<T>(Future<T> Function() action) async {
    beginTrusted();
    try {
      return await action();
    } finally {
      Timer(const Duration(milliseconds: 1000), endTrusted);
    }
  }
}
