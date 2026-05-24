import 'package:flutter/material.dart';

class IconHelper {
  /// Створює іконку з динамічного коду (наприклад, з БД).
  /// Ізолює роботу з динамічними даними в єдиному місці.
  static IconData getIcon(
    int codePoint, {
    String fontFamily = 'MaterialIcons',
  }) {
    // Це єдине місце в усьому проєкті, де ми повідомляємо компілятору,
    // що свідомо беремо коди з бази даних.
    // ignore: non_const_argument_for_const_parameter
    return IconData(codePoint, fontFamily: fontFamily);
  }
}
