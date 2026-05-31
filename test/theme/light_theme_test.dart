import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/theme/light_theme.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';

void main() {
  group('Light Theme Configuration Tests', () {
    final theme = lightTheme;

    test('1. Базові налаштування (Brightness та Colors)', () {
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFE9EEF5));
      expect(theme.colorScheme.primary, Colors.black);
    });

    test('2. Перевірка AppColorsExtension (Light Palette)', () {
      final colors = theme.extension<AppColorsExtension>();

      expect(colors, isNotNull);
      // Перевіряємо специфічні для світлої теми кольори градієнта
      expect(colors!.bgGradientStart, const Color(0xFFD1D9E6));
      expect(colors.bgGradientEnd, const Color(0xFFE9EEF5));
      expect(colors.cardBg, Colors.white);
      expect(colors.textMain, const Color(0xFF1C1C1E));
      expect(colors.accent, const Color(0xFF2950A0));
    });

    test('3. Тема діалогів та шторок (Strict Radii)', () {
      // Перевірка радіуса діалогу (16)
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(dialogShape.borderRadius, BorderRadius.circular(16));
      expect(theme.dialogTheme.backgroundColor, Colors.white);

      // Перевірка радіуса BottomSheet (24)
      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(
        sheetShape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
    });

    test('4. Тема карток (CardTheme)', () {
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(12));
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.cardTheme.elevation, 0);
    });

    test('5. Тема полів вводу (InputDecoration)', () {
      final inputTheme = theme.inputDecorationTheme;

      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, const Color(0xFFF2F2F7));

      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(8));
    });

    test('6. Тема кнопок (Elevated & Text buttons)', () {
      // Elevated Button (Black bg, White text)
      final elevatedStyle = theme.elevatedButtonTheme.style!;
      final shape = elevatedStyle.shape?.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));

      expect(elevatedStyle.backgroundColor?.resolve({}), Colors.black);
      expect(elevatedStyle.foregroundColor?.resolve({}), Colors.white);

      // Text Button (Grayish bg)
      final textStyle = theme.textButtonTheme.style!;
      expect(textStyle.backgroundColor?.resolve({}), const Color(0xFFF2F2F7));
      final textShape = textStyle.shape?.resolve({}) as RoundedRectangleBorder;
      expect(textShape.borderRadius, BorderRadius.circular(8));
    });
  });
}
