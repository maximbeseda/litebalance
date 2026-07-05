import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/theme/app_theme.dart';
import 'package:litebalance/theme/light_theme.dart';
import 'package:litebalance/theme/dark_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('1. allThemes містить правильні ключі та переклади', () {
      final themes = AppTheme.allThemes;

      expect(themes.length, 2);
      expect(themes['light'], 'theme_light');
      expect(themes['dark'], 'theme_dark');
    });

    test('2. getTheme повертає lightTheme для ключа "light"', () {
      final theme = AppTheme.getTheme('light');

      // Перевіряємо за яскравістю, щоб переконатися, що це світла тема
      expect(theme.brightness, Brightness.light);
      // Або пряме порівняння об'єктів, якщо вони експортуються як константи
      expect(theme, lightTheme);
    });

    test('3. getTheme повертає darkTheme для ключа "dark"', () {
      final theme = AppTheme.getTheme('dark');

      expect(theme.brightness, Brightness.dark);
      expect(theme, darkTheme);
    });

    test('4. getTheme повертає lightTheme (дефолт) для неіснуючого ключа', () {
      final theme = AppTheme.getTheme('random_string');

      expect(theme, lightTheme);
    });

    test('5. getTheme повертає lightTheme (дефолт) для порожнього рядка', () {
      final theme = AppTheme.getTheme('');

      expect(theme, lightTheme);
    });
  });
}
