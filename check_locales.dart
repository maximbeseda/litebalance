// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() async {
  final translationsDir = Directory('assets/translations');

  if (!await translationsDir.exists()) {
    print('❌ Папку ${translationsDir.path} не знайдено!');
    return;
  }

  // Отримуємо всі JSON файли з папки перекладів
  final jsonFiles = translationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  if (jsonFiles.isEmpty) {
    print('❌ JSON файли не знайдені в assets/translations!');
    return;
  }

  // Читаємо перший файл (наприклад, uk.json) як базовий список усіх ключів
  final String baseJson = await jsonFiles.first.readAsString();
  final Map<String, dynamic> baseMap = jsonDecode(baseJson);
  final List<String> allKeys = baseMap.keys.toList();

  final libDir = Directory('lib');
  final List<File> dartFiles = [];

  // Збираємо всі .dart файли
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      dartFiles.add(entity);
    }
  }

  final Set<String> usedKeys = {};

  print('🔍 Сканую файли коду...');

  // Шукаємо ключі у всіх файлах
  for (final file in dartFiles) {
    final content = await file.readAsString();

    for (final key in allKeys) {
      if (usedKeys.contains(key)) continue;

      // Перевіряємо, чи є ключ у файлі (в одинарних або подвійних лапках)
      if (content.contains("'$key'") || content.contains('"$key"')) {
        usedKeys.add(key);
      }
    }
  }

  // Визначаємо, які ключі не використовуються
  final unusedKeys = allKeys.where((k) => !usedKeys.contains(k)).toList();

  print('\n📊 --- РЕЗУЛЬТАТИ ---');
  print('Всього ключів перевірено: ${allKeys.length}');
  print('Використовуються: ${usedKeys.length}');
  print('На видалення: ${unusedKeys.length}');

  if (unusedKeys.isEmpty) {
    print('\n✅ Усе чисто! Зайвих ключів немає.');
    return;
  }

  print(
    '\n🗑️ Видаляю ${unusedKeys.length} ключів з усіх файлів локалізації...',
  );

  // Регулярний вираз для пошуку ключа в рядку: "some_key": "some value"
  final keyRegExp = RegExp(r'^\s*"([^"]+)"\s*:');

  // Проходимось по кожному JSON файлу
  for (final file in jsonFiles) {
    final content = await file.readAsString();
    final lines = content.split('\n');
    final newLines = <String>[];

    for (final line in lines) {
      final match = keyRegExp.firstMatch(line);

      if (match != null) {
        final key = match.group(1)!;
        // Якщо ключ є у списку на видалення - просто пропускаємо цей рядок
        if (unusedKeys.contains(key)) {
          continue;
        }
      }

      // Всі інші рядки (пусті рядки, дужки, потрібні ключі) залишаємо як є
      newLines.add(line);
    }

    // Збираємо текст назад в єдиний файл
    String newContent = newLines.join('\n');

    // МАГІЯ: Якщо ми видалили останній ключ перед "}",
    // у попереднього ключа могла залишитися кома в кінці рядка (що ламає JSON).
    // Цей рядок знаходить зайву кому перед закриваючою дужкою і видаляє її.
    newContent = newContent.replaceAll(RegExp(r',(\s*\})'), r'$1');

    // Перезаписуємо файл
    await file.writeAsString(newContent);
    print('✅ Очищено файл: ${file.path.split(Platform.pathSeparator).last}');
  }

  print(
    '\n🎉 Готово! Проєкт став легшим на ${unusedKeys.length} ключів. Всі ваші пусті рядки збережено!',
  );
}
