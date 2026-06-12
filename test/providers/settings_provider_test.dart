import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/currency_repository.dart';

// 1. МОК для репозиторію
class MockCurrencyRepository extends Mock implements CurrencyRepository {}

// 2. ШПИГУН для категорій
class SpyCategoryNotifier extends CategoryNotifier {
  String? updatedOldBase;
  @override
  CategoryState build() => CategoryState(
    incomes: [],
    accounts: [],
    expenses: [],
    archivedCategories: [],
    deletedCategories: [],
    isLoading: false,
  );

  @override
  Future<void> updateBaseCurrencyForCategories(
    String oldBase,
    String newBase,
  ) async {
    updatedOldBase = oldBase;
  }
}

void main() {
  late MockCurrencyRepository mockApi;
  late SharedPreferences prefs;

  Future<ProviderContainer> createContainer() async {
    mockApi = MockCurrencyRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // Заглушка для стартового запуску
    when(
      () => mockApi.fetchLatestRates(any()),
    ).thenAnswer((_) async => {'USD': 40.0, 'UAH': 1.0});

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyRepoProvider.overrideWithValue(mockApi),
        categoryProvider.overrideWith(() => SpyCategoryNotifier()),
      ],
    );

    addTearDown(container.dispose);

    // Чекаємо завершення Future.microtask у методі build()
    await Future.delayed(const Duration(milliseconds: 50));
    return container;
  }

  group('SettingsNotifier - 100% Покриття', () {
    test(
      '1. convertAmount та convertToBase рахують правильно (вкл. Edge Cases)',
      () async {
        final container = await createContainer();
        final notifier = container.read(settingsProvider.notifier);

        notifier.state = notifier.state.copyWith(
          baseCurrency: 'UAH',
          exchangeRates: {'USD': 0.025, 'JPY': 4.0, 'ZERO': 0.0},
        );

        // convertAmount
        final resultAmount = notifier.convertAmount(
          amount: 10000,
          fromCurrency: 'USD',
          toCurrency: 'JPY',
        );
        expect(resultAmount, 1600000); // 100 / 0.025 * 4

        // convertToBase
        expect(notifier.convertToBase(100, 'UAH'), 100); // Якщо базова валюта
        expect(
          notifier.convertToBase(100, 'UNKNOWN'),
          100,
        ); // Якщо курсу немає (null)
        expect(notifier.convertToBase(100, 'ZERO'), 100); // Якщо курс 0
        expect(
          notifier.convertToBase(10000, 'USD'),
          400000,
        ); // Нормальна конвертація
      },
    );

    test('2. getRateForDate перевіряє поточну дату, кеш та API', () async {
      final container = await createContainer();
      final notifier = container.read(settingsProvider.notifier);

      notifier.state = notifier.state.copyWith(
        baseCurrency: 'UAH',
        exchangeRates: {'USD': 40.0},
        historicalCache: {
          '2022-01-01': {'USD': 28.0},
        },
      );

      final today = DateTime.now();
      final pastDate = DateTime(2022, 1, 1);
      final missingDate = DateTime(2023, 5, 5);

      // A) Перевірка базової валюти
      expect(await notifier.getRateForDate('UAH', today), 1.0);

      // B) Перевірка поточної дати (бере з поточних exchangeRates)
      expect(await notifier.getRateForDate('USD', today), 40.0);

      // C) Перевірка історичного кешу (дата вже є в мапі)
      expect(await notifier.getRateForDate('USD', pastDate), 28.0);

      // D) Запит до API (якщо немає в кеші)
      when(
        () => mockApi.fetchHistoricalRates('UAH', missingDate),
      ).thenAnswer((_) async => {'USD': 36.5});

      final fetchedRate = await notifier.getRateForDate('USD', missingDate);
      expect(fetchedRate, 36.5);

      // Перевіряємо, чи зберігся результат у кеш
      final newState = container.read(settingsProvider);
      expect(newState.historicalCache.containsKey('2023-05-05'), true);

      // E) API повернуло null (немає курсу)
      when(
        () => mockApi.fetchHistoricalRates('UAH', missingDate),
      ).thenAnswer((_) async => null);
      final nullRate = await notifier.getRateForDate('EUR', missingDate);
      expect(nullRate, null);
    });

    test(
      '3. setBaseCurrency: Успішна зміна та Скасування при помилці API',
      () async {
        final container = await createContainer();
        final notifier = container.read(settingsProvider.notifier);
        final spyCategory =
            container.read(categoryProvider.notifier) as SpyCategoryNotifier;

        // Спроба змінити на ту ж саму валюту (Ранній вихід)
        await notifier.setBaseCurrency('UAH');
        expect(spyCategory.updatedOldBase, null); // Метод не пішов далі

        // Спроба змінити, але API повернув null
        when(
          () => mockApi.fetchLatestRates('EUR'),
        ).thenAnswer((_) async => null);
        await notifier.setBaseCurrency('EUR');
        expect(notifier.state.baseCurrency, 'UAH'); // Валюта НЕ змінилася

        // Успішна зміна
        when(
          () => mockApi.fetchLatestRates('USD'),
        ).thenAnswer((_) async => {'UAH': 0.025});
        await notifier.setBaseCurrency('USD');
        expect(notifier.state.baseCurrency, 'USD');
        expect(spyCategory.updatedOldBase, 'UAH'); // Інтеграція спрацювала
      },
    );

    test(
      '4. toggleSelectedCurrency додає, видаляє та ігнорує базову',
      () async {
        final container = await createContainer();
        final notifier = container.read(settingsProvider.notifier);

        final base = notifier.state.baseCurrency;

        // Базова валюта не видаляється
        await notifier.toggleSelectedCurrency(base);
        expect(notifier.state.selectedCurrencies.contains(base), true);

        // Додавання і видалення сторонньої
        await notifier.toggleSelectedCurrency('CAD');
        expect(notifier.state.selectedCurrencies.contains('CAD'), true);

        await notifier.toggleSelectedCurrency('CAD');
        expect(notifier.state.selectedCurrencies.contains('CAD'), false);
      },
    );

    test(
      '5. forceUpdateRates повертає false, якщо API не відповідає',
      () async {
        final container = await createContainer();
        final notifier = container.read(settingsProvider.notifier);

        // API повертає null
        when(
          () => mockApi.fetchLatestRates(any()),
        ).thenAnswer((_) async => null);
        final result = await notifier.forceUpdateRates();

        expect(result, false); // Оновлення не відбулося
      },
    );

    test('6. Дрібні методи: Wi-Fi та дати бекапів', () async {
      final container = await createContainer();
      final notifier = container.read(settingsProvider.notifier);

      // Wi-Fi
      await notifier.toggleSyncOnlyViaWifi(true);
      expect(notifier.state.syncOnlyViaWifi, true);
      expect(prefs.getBool('sync_only_wifi'), true);

      // Cloud Backup
      await notifier.updateCloudBackupTime();
      expect(notifier.state.lastCloudBackup, isNotNull);
      expect(prefs.getString('last_cloud_backup'), isNotNull);

      // File Backup
      await notifier.updateFileBackupTime();
      expect(notifier.state.lastFileBackup, isNotNull);
      expect(prefs.getString('last_file_backup'), isNotNull);
    });
  });
}
