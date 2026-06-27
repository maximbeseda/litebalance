import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litebalance/widgets/common/app_lock_gate.dart';

void main() {
  group('resolveLockTimeoutMs', () {
    test('повертає дефолт (5 хв), коли значення не збережене', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(resolveLockTimeoutMs(prefs), kDefaultAutoLockTimeoutMs);
      expect(kDefaultAutoLockTimeoutMs, 5 * 60 * 1000);
    });

    test('повертає збережене значення користувача', () async {
      SharedPreferences.setMockInitialValues({kLockTimeoutKey: 30 * 1000});
      final prefs = await SharedPreferences.getInstance();

      expect(resolveLockTimeoutMs(prefs), 30 * 1000);
    });

    test('значення 0 (одразу) поважається, а не підмінюється дефолтом', () async {
      SharedPreferences.setMockInitialValues({kLockTimeoutKey: 0});
      final prefs = await SharedPreferences.getInstance();

      expect(resolveLockTimeoutMs(prefs), 0);
    });
  });
}
