import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:litebalance/providers/home_screen_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('HomeScreenController Tests', () {
    test(
      '1. Початковий стан має бути правильним (isEditMode: false, selectedIds: порожньо)',
      () {
        final state = container.read(homeScreenControllerProvider);

        expect(state.isEditMode, false);
        expect(state.selectedIds.isEmpty, true);
      },
    );

    test('2. toggleEditMode змінює режим та очищає вибрані ID', () {
      final notifier = container.read(homeScreenControllerProvider.notifier);

      // Вмикаємо режим редагування
      notifier.toggleEditMode();
      var state = container.read(homeScreenControllerProvider);

      expect(state.isEditMode, true);
      expect(state.selectedIds.isEmpty, true);

      // Імітуємо вибір кількох категорій користувачем
      notifier.toggleSelection('cat_1');
      notifier.toggleSelection('cat_2');
      state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.length, 2);

      // Вимикаємо режим редагування (має автоматично очистити список)
      notifier.toggleEditMode();
      state = container.read(homeScreenControllerProvider);

      expect(state.isEditMode, false);
      expect(
        state.selectedIds.isEmpty,
        true,
        reason: 'Список має очищатися при виході з режиму редагування',
      );
    });

    test('3. toggleSelection додає та видаляє ID зі списку (Тогл-ефект)', () {
      final notifier = container.read(homeScreenControllerProvider.notifier);

      // Клік 1: Додаємо 'item_1'
      notifier.toggleSelection('item_1');
      var state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.contains('item_1'), true);
      expect(state.selectedIds.length, 1);

      // Клік 2: Додаємо 'item_2'
      notifier.toggleSelection('item_2');
      state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.contains('item_2'), true);
      expect(state.selectedIds.length, 2);

      // Клік 3: Видаляємо 'item_1' (клікнули повторно по тому ж елементу)
      notifier.toggleSelection('item_1');
      state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.contains('item_1'), false);
      expect(state.selectedIds.contains('item_2'), true);
      expect(state.selectedIds.length, 1);
    });

    test('4. clearSelection повністю очищає список вибраних ID', () {
      final notifier = container.read(homeScreenControllerProvider.notifier);

      notifier.toggleSelection('item_1');
      notifier.toggleSelection('item_2');
      var state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.length, 2);

      // Примусове очищення
      notifier.clearSelection();
      state = container.read(homeScreenControllerProvider);
      expect(state.selectedIds.isEmpty, true);
    });
  });

  group('HomeScreenState Unit Tests', () {
    test('copyWith працює коректно і зберігає старі значення', () {
      final state = HomeScreenState(isEditMode: false, selectedIds: {'1'});

      // Змінюємо тільки isEditMode
      final newState = state.copyWith(isEditMode: true);

      expect(newState.isEditMode, true);
      // selectedIds має залишитися без змін
      expect(newState.selectedIds, {'1'});
    });
  });
}
