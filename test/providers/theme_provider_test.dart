import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litebalance/providers/all_providers.dart';

void main() {
  Future<ProviderContainer> createContainer({
    Map<String, Object> initialData = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialData);
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeNotifier - Persistence', () {
    test('setTheme змінює стан і зберігає його на диск', () async {
      final container = await createContainer();

      // 👇 ВИПРАВЛЕНО: Використовуємо themeProvider (або ту назву, яка у вас в all_providers.dart)
      final notifier = container.read(themeProvider.notifier);

      // 1. Дія: користувач вибирає темну тему
      notifier.setTheme('dark');

      // 2. Перевірка: чи змінився стан провайдера
      expect(container.read(themeProvider), 'dark');

      // 3. Перевірка: чи записалися дані фізично в SharedPreferences
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString('current_theme_id'), 'dark');
    });

    test('build завантажує збережену тему при старті', () async {
      // Імітуємо ситуацію, коли користувач вже раніше обрав 'amoled' тему
      final container = await createContainer(
        initialData: {'current_theme_id': 'amoled'},
      );

      // 👇 ВИПРАВЛЕНО
      final themeId = container.read(themeProvider);

      expect(themeId, 'amoled');
    });
  });
}
