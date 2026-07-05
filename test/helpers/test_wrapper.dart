import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:litebalance/theme/app_theme.dart'; // Перевірте, чи правильний шлях до вашого файлу

Widget makeTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
  ThemeData? theme, // Додали параметр теми
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          theme ??
          AppTheme.getTheme(
            'light',
          ), // Використовуємо вашу світлу тему за замовчуванням
      home: Scaffold(
        body: Center(
          child: child,
        ), // Center додано, щоб віджет не розтягувався на весь екран
      ),
    ),
  );
}
