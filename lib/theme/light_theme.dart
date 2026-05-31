import 'package:flutter/material.dart';
import 'app_colors_extension.dart';

final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFE9EEF5),

  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.black,
    primary: Colors.black,
    brightness: Brightness.light,
  ),

  extensions: [
    const AppColorsExtension(
      bgGradientStart: Color(0xFFD1D9E6),
      bgGradientEnd: Color(0xFFE9EEF5),
      cardBg: Colors.white,
      textMain: Color(0xFF1C1C1E),
      textSecondary: Color(0xFF636366),
      income: Color(0xFF1E8E3E),
      expense: Color(0xFFE53935),
      iconBg: Color(0x0D000000), // Colors.black.withValues(alpha: 0.05)
      accent: Color(0xFF2950A0),
      warning: Color(0xFFF59E0B),
      divider: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1)
      shadow: Color(0x0D000000), // Colors.black.withValues(alpha: 0.05)
    ),
  ],

  // СТРОГІ ДІАЛОГИ (радіус 16 замість 28)
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shadowColor: Colors.black.withValues(alpha: 0.2),
  ),

  // НИЖНІ ШТОРКИ (BottomSheet) - додаємо глобально
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ), // Трохи більше для шторки виглядає краще
    ),
  ),

  // КАРТКИ (Card) - додаємо глобально
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),

  // СТРОГІ ПОЛЯ ВВОДУ (радіус 8 замість 16)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF2F2F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.blue, width: 2),
    ),
  ),

  // СТРОГІ КНОПКИ (радіус 8 замість 16)
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: const Color(0xFFF2F2F7),
      foregroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
