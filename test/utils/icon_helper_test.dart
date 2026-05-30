import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/utils/icon_helper.dart';

void main() {
  group('IconHelper Tests', () {
    test('getIcon повертає коректний IconData', () {
      // Вибираємо довільний знайомий код іконки, наприклад Icons.home (0xe318)
      const int homeCodePoint = 0xe318;

      final icon = IconHelper.getIcon(homeCodePoint);

      expect(icon, isA<IconData>());
      expect(icon.codePoint, equals(homeCodePoint));
      expect(icon.fontFamily, equals('MaterialIcons'));
    });

    test('getIcon працює з різними шрифтами', () {
      const int code = 0xe000;
      final icon = IconHelper.getIcon(code, fontFamily: 'CupertinoIcons');

      expect(icon.fontFamily, equals('CupertinoIcons'));
    });
  });
}
