import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/utils/app_constants.dart';

void main() {
  // Ініціалізація зв'язків Flutter (необхідно для роботи з іконками та контекстом у тестах)
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConstants Tests', () {
    test('languages повинен містити базові локалі', () {
      expect(AppConstants.languages.containsKey('uk'), true);
      expect(AppConstants.languages.containsKey('en'), true);
      expect(AppConstants.languages['uk'], 'Українська');
    });

    test('groupedIcons повинен повертати непорожній список категорій', () {
      final groups = AppConstants.groupedIcons;

      expect(groups.isNotEmpty, true);
      // Перевіряємо, що кожна категорія має хоча б одну іконку
      expect(groups.values.any((list) => list.isEmpty), false);
    });

    test('allIcons повинен збирати всі іконки в один плоский список', () {
      final totalIconsInGroups = AppConstants.groupedIcons.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );

      final flattenedIcons = AppConstants.allIcons;

      expect(flattenedIcons.length, totalIconsInGroups);
      expect(flattenedIcons.contains(Icons.account_balance_wallet), true);
    });

    test('Кожна категорія іконок повинна мати унікальну назву (ключ)', () {
      final groupNames = AppConstants.groupedIcons.keys.toList();
      final uniqueNames = groupNames.toSet();

      expect(
        groupNames.length,
        uniqueNames.length,
        reason: 'Знайдено дублікати в назвах категорій іконок',
      );
    });
  });
}
