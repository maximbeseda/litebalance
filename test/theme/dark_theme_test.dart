import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/theme/dark_theme.dart';
import 'package:litebalance/theme/app_colors_extension.dart';

void main() {
  group('Dark Theme Configuration Tests', () {
    final theme = darkTheme;

    test('1. Базові налаштування (Brightness та Colors)', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1C1C1E));
      expect(theme.colorScheme.primary, Colors.white);
    });

    test('2. Перевірка AppColorsExtension (Custom Colors)', () {
      final colors = theme.extension<AppColorsExtension>();

      expect(colors, isNotNull);
      expect(colors!.bgGradientStart, const Color(0xFF2C2C2E));
      expect(colors.income, const Color(0xFF1E8E3E));
      expect(colors.expense, const Color(0xFFE53935));
      expect(colors.accent, const Color(0xFF5A7DCD));
    });

    test('3. Тема діалогів та шторок (Strict Radii)', () {
      // Перевірка радіуса діалогу (має бути 16)
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(dialogShape.borderRadius, BorderRadius.circular(16));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFF2C2C2E));

      // Перевірка радіуса BottomSheet (має бути 24)
      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(
        sheetShape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
    });

    test('4. Тема полів вводу (InputDecoration)', () {
      final inputTheme = theme.inputDecorationTheme;

      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, const Color(0xFF3A3A3C));

      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(8));
    });

    test('5. Тема кнопок (Elevated & Text buttons)', () {
      // Перевірка Elevated Button
      final elevatedStyle = theme.elevatedButtonTheme.style!;
      // Використовуємо resolve для отримання реального значення
      final shape = elevatedStyle.shape?.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));

      final bgColor = elevatedStyle.backgroundColor?.resolve({});
      expect(bgColor, Colors.white);

      // Перевірка Text Button
      final textStyle = theme.textButtonTheme.style!;
      final textBg = textStyle.backgroundColor?.resolve({});
      // 👇 ВИПРАВЛЕНО: Очікуємо новий напівпрозорий колір (10% білого)
      expect(textBg, const Color(0x1AFFFFFF));
    });
  });
}
