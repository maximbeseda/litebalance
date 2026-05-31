import 'package:flutter/material.dart';
import 'app_colors_extension.dart';

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),

  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.white,
    primary: Colors.white,
    brightness: Brightness.dark,
  ),

  extensions: [
    const AppColorsExtension(
      bgGradientStart: Color(0xFF2C2C2E),
      bgGradientEnd: Color(0xFF1C1C1E),
      cardBg: Color(0xFF3A3A3C),
      textMain: Colors.white,
      textSecondary: Colors.white70,
      income: Color(0xFF1E8E3E),
      expense: Color(0xFFE53935),
      iconBg: Color(0x1AFFFFFF), // Colors.white.withValues(alpha: 0.1)
      accent: Color(0xFF5A7DCD),
      warning: Color(0xFFFBBF24),
      divider: Color(0x1FFFFFFF), // Colors.white.withValues(alpha: 0.12)
      shadow: Color(0x40000000), // Colors.black.withValues(alpha: 0.25)
    ),
  ],

  // СТРОГІ ДІАЛОГИ (радіус 16 замість 28)
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: const Color(0xFF2C2C2E),
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shadowColor: Colors.black,
  ),

  // НИЖНІ ШТОРКИ
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF3A3A3C),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),

  // КАРТКИ
  cardTheme: CardThemeData(
    color: const Color(0xFF3A3A3C),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),

  // СТРОГІ ПОЛЯ ВВОДУ (радіус 8 замість 16)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF3A3A3C),
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
      borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
    ),
  ),

  // СТРОГІ КНОПКИ (радіус 8 замість 16)
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: const Color(0x1AFFFFFF),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
