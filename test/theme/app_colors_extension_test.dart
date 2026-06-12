import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/theme/app_colors_extension.dart';

void main() {
  group('AppColorsExtension Tests', () {
    const baseColors = AppColorsExtension(
      bgGradientStart: Color(0xFF000000),
      bgGradientEnd: Color(0xFF111111),
      cardBg: Color(0xFF222222),
      textMain: Color(0xFF333333),
      textSecondary: Color(0xFF444444),
      income: Color(0xFF555555),
      expense: Color(0xFF666666),
      iconBg: Color(0xFF777777),
      accent: Color(0xFF888888),
    );

    test('1. Конструктор правильно присвоює значення', () {
      expect(baseColors.bgGradientStart, const Color(0xFF000000));
      expect(baseColors.accent, const Color(0xFF888888));
    });

    test('2. copyWith правильно оновлює окремі кольори', () {
      // 👇 ДОДАНО ЯВНЕ ПРИВЕДЕННЯ ТИПУ (as AppColorsExtension)
      final updated =
          baseColors.copyWith(
                accent: const Color(0xFFFFFFFF),
                textMain: const Color(0xFF000000),
              )
              as AppColorsExtension;

      expect(updated.accent, const Color(0xFFFFFFFF));
      expect(updated.textMain, const Color(0xFF000000));
      expect(updated.cardBg, baseColors.cardBg);
    });

    test('3. lerp правильно інтерполює кольори', () {
      const targetColors = AppColorsExtension(
        bgGradientStart: Color(0xFFFFFFFF),
        bgGradientEnd: Color(0xFFFFFFFF),
        cardBg: Color(0xFFFFFFFF),
        textMain: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFFFFFFF),
        income: Color(0xFFFFFFFF),
        expense: Color(0xFFFFFFFF),
        iconBg: Color(0xFFFFFFFF),
        accent: Color(0xFFFFFFFF),
      );

      // 👇 ДОДАНО ЯВНЕ ПРИВЕДЕННЯ ТИПУ
      final lerped = baseColors.lerp(targetColors, 0.5) as AppColorsExtension;

      expect(
        lerped.bgGradientStart,
        Color.lerp(
          baseColors.bgGradientStart,
          targetColors.bgGradientStart,
          0.5,
        ),
      );
      expect(
        lerped.accent,
        Color.lerp(baseColors.accent, targetColors.accent, 0.5),
      );
    });

    test('4. lerp повертає оригінал при неправильних аргументах', () {
      final lerpWithNull = baseColors.lerp(null, 0.5);
      expect(lerpWithNull, baseColors);

      // Передаємо інший тип, щоб перевірити гілку "return this"
      final lerpWithOther = baseColors.lerp(_WrongThemeExtension(), 0.5);
      expect(lerpWithOther, baseColors);
    });
  });
}

// 👇 ВИПРАВЛЕНО: Клас має наслідуватись від ThemeExtension<AppColorsExtension>
// щоб його можна було передати в метод lerp, але він не пройде перевірку (is! AppColorsExtension)
class _WrongThemeExtension extends ThemeExtension<AppColorsExtension> {
  @override
  ThemeExtension<AppColorsExtension> copyWith() => this;
  @override
  ThemeExtension<AppColorsExtension> lerp(other, t) => this;
}
