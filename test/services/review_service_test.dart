import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litebalance/services/review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const day = 24 * 60 * 60 * 1000;
  final now = DateTime(2026, 8, 3).millisecondsSinceEpoch;

  // Стан, що задовольняє ВСІ умови: 6 запусків, встановлено 10 днів тому,
  // прохань ще не було.
  Map<String, Object> okPrefs() => {
    'review_launch_count': 6,
    'review_install_date': now - 10 * day,
  };

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('ReviewService.shouldRequestReview', () {
    test('усі умови виконані -> true', () async {
      final prefs = await prefsWith(okPrefs());
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 12,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('замало транзакцій (<10) -> false', () async {
      final prefs = await prefsWith(okPrefs());
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 9,
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('замало запусків (<5) -> false', () async {
      final prefs = await prefsWith({
        'review_launch_count': 4,
        'review_install_date': now - 10 * day,
      });
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 20,
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('минуло менше 3 днів від встановлення -> false', () async {
      final prefs = await prefsWith({
        'review_launch_count': 6,
        'review_install_date': now - 1 * day,
      });
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 20,
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('дата встановлення відсутня -> false', () async {
      final prefs = await prefsWith({'review_launch_count': 6});
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 20,
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('нещодавно вже просили (<120 днів) -> false', () async {
      final prefs = await prefsWith({
        ...okPrefs(),
        'review_last_request': now - 30 * day,
      });
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 20,
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('попереднє прохання давно (>120 днів) -> true', () async {
      final prefs = await prefsWith({
        ...okPrefs(),
        'review_last_request': now - 200 * day,
      });
      expect(
        ReviewService.shouldRequestReview(
          prefs: prefs,
          transactionCount: 20,
          nowMs: now,
        ),
        isTrue,
      );
    });
  });

  group('ReviewService.recordAppOpen', () {
    test('перший запуск фіксує дату і лічильник = 1', () async {
      final prefs = await prefsWith({});
      await ReviewService.recordAppOpen(prefs);
      expect(prefs.getInt('review_launch_count'), 1);
      expect(prefs.getInt('review_install_date'), isNotNull);
    });

    test('наступні запуски інкрементують лічильник, дата не змінюється',
        () async {
      final installed = now - 5 * day;
      final prefs = await prefsWith({
        'review_launch_count': 3,
        'review_install_date': installed,
      });
      await ReviewService.recordAppOpen(prefs);
      expect(prefs.getInt('review_launch_count'), 4);
      expect(prefs.getInt('review_install_date'), installed);
    });
  });
}
