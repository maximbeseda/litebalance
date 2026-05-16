import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/storage_service.dart';
import '../services/currency_repository.dart';
import 'all_providers.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class CurrencyRepo extends _$CurrencyRepo {
  @override
  CurrencyRepository build() {
    return FawazahmedApi();
  }
}

class SettingsState {
  final String baseCurrency;
  final List<String> selectedCurrencies;
  final Map<String, double> exchangeRates;
  final DateTime? lastRatesUpdate;
  final Map<String, dynamic> historicalCache;

  // Поля для відстеження бекапів
  final DateTime? lastCloudBackup;
  final DateTime? lastFileBackup;

  // Поле: Синхронізація лише по Wi-Fi
  final bool syncOnlyViaWifi;

  SettingsState({
    required this.baseCurrency,
    required this.selectedCurrencies,
    required this.exchangeRates,
    this.lastRatesUpdate,
    required this.historicalCache,
    this.lastCloudBackup,
    this.lastFileBackup,
    this.syncOnlyViaWifi = false,
  });

  SettingsState copyWith({
    String? baseCurrency,
    List<String>? selectedCurrencies,
    Map<String, double>? exchangeRates,
    DateTime? lastRatesUpdate,
    Map<String, dynamic>? historicalCache,
    DateTime? lastCloudBackup,
    DateTime? lastFileBackup,
    bool? syncOnlyViaWifi,
  }) {
    return SettingsState(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      lastRatesUpdate: lastRatesUpdate ?? this.lastRatesUpdate,
      historicalCache: historicalCache ?? this.historicalCache,
      lastCloudBackup: lastCloudBackup ?? this.lastCloudBackup,
      lastFileBackup: lastFileBackup ?? this.lastFileBackup,
      syncOnlyViaWifi: syncOnlyViaWifi ?? this.syncOnlyViaWifi,
    );
  }
}

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  CurrencyRepository get _api => ref.read(currencyRepoProvider);

  // Зручний геттер для доступу до StorageService
  StorageService get _storage =>
      StorageService(ref.read(sharedPreferencesProvider));

  @override
  SettingsState build() {
    ref.onDispose(() {
      debugPrint('SettingsNotifier disposed: clearing memory');
    });

    // Отримуємо доступ до SharedPreferences
    final prefs = ref.read(sharedPreferencesProvider);

    final String base = _storage.getBaseCurrency();
    final List<String> selected = _storage.getSelectedCurrencies();

    // Зчитуємо дати та налаштування Wi-Fi
    final String? lastCloud = prefs.getString('last_cloud_backup');
    final String? lastFile = prefs.getString('last_file_backup');
    final bool wifiOnly = prefs.getBool('sync_only_wifi') ?? false;

    if (!selected.contains(base)) {
      selected.insert(0, base);
    } else {
      selected.remove(base);
      selected.insert(0, base);
    }

    final rates = _storage.getExchangeRates();
    final lastUpdate = _storage.getLastRatesUpdateTime();
    final cache = _storage.getHistoricalRatesCache();

    final initialState = SettingsState(
      baseCurrency: base,
      selectedCurrencies: selected,
      exchangeRates: rates,
      lastRatesUpdate: lastUpdate,
      historicalCache: cache,
      lastCloudBackup: lastCloud != null ? DateTime.tryParse(lastCloud) : null,
      lastFileBackup: lastFile != null ? DateTime.tryParse(lastFile) : null,
      syncOnlyViaWifi: wifiOnly,
    );

    unawaited(Future.microtask(() => _checkRatesUpdate(initialState)));

    return initialState;
  }

  // Зміна налаштування Wi-Fi
  Future<void> toggleSyncOnlyViaWifi(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool('sync_only_wifi', value);
    state = state.copyWith(syncOnlyViaWifi: value);
  }

  Future<void> _checkRatesUpdate(SettingsState currentState) async {
    final now = DateTime.now();
    if (currentState.lastRatesUpdate == null ||
        now.difference(currentState.lastRatesUpdate!).inHours >= 12) {
      await forceUpdateRates();
      if (!ref.mounted) return;
    }
  }

  Future<double?> getRateForDate(String currencyCode, DateTime date) async {
    if (currencyCode == state.baseCurrency) return 1.0;

    final String dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    if (state.historicalCache.containsKey(dateKey)) {
      final dayRates = state.historicalCache[dateKey] as Map;
      if (dayRates.containsKey(currencyCode)) {
        return (dayRates[currencyCode] as num).toDouble();
      }
    }

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday || date.isAfter(now)) {
      return state.exchangeRates[currencyCode];
    }

    final historicalRates = await _api.fetchHistoricalRates(
      state.baseCurrency,
      date,
    );

    if (historicalRates != null && historicalRates.isNotEmpty) {
      final newCache = Map<String, dynamic>.from(state.historicalCache);
      newCache[dateKey] = historicalRates;

      state = state.copyWith(historicalCache: newCache);
      await _storage.saveHistoricalRatesCache(newCache);

      if (historicalRates.containsKey(currencyCode)) {
        return historicalRates[currencyCode]!;
      }
    }
    return null;
  }

  Future<void> setBaseCurrency(String code) async {
    if (state.baseCurrency == code) return;

    final oldBaseCurrency = state.baseCurrency;
    final newRates = await _api.fetchLatestRates(code);

    if (newRates == null) {
      debugPrint(
        'Помилка: не вдалося отримати курси для $code. Міграцію скасовано.',
      );
      return;
    }

    final now = DateTime.now();

    await _storage.saveBaseCurrency(code);
    await _storage.saveExchangeRates(newRates);
    await _storage.setLastRatesUpdateTime(now);

    final List<String> newSelected = List.from(state.selectedCurrencies);
    newSelected.remove(code);
    newSelected.insert(0, code);
    await _storage.setSelectedCurrencies(newSelected);
    await _storage.saveHistoricalRatesCache({});

    await ref
        .read(categoryProvider.notifier)
        .updateBaseCurrencyForCategories(oldBaseCurrency, code);

    state = state.copyWith(
      baseCurrency: code,
      selectedCurrencies: newSelected,
      exchangeRates: newRates,
      lastRatesUpdate: now,
      historicalCache: {},
    );

    await _storage.saveHistoricalRatesCache({});
  }

  Future<void> toggleSelectedCurrency(String code) async {
    final List<String> newSelected = List.from(state.selectedCurrencies);

    if (newSelected.contains(code)) {
      if (code == state.baseCurrency) return;
      newSelected.remove(code);
    } else {
      newSelected.add(code);
    }

    await _storage.setSelectedCurrencies(newSelected);
    state = state.copyWith(selectedCurrencies: newSelected);
  }

  Future<bool> forceUpdateRates() async {
    debugPrint('Завантаження нових курсів для: ${state.baseCurrency}');

    final newRates = await _api.fetchLatestRates(state.baseCurrency);
    if (!ref.mounted) return false;

    if (newRates != null) {
      final now = DateTime.now();
      await _storage.saveExchangeRates(newRates);

      if (!ref.mounted) return true;

      await _storage.setLastRatesUpdateTime(now);

      if (!ref.mounted) return true;

      state = state.copyWith(exchangeRates: newRates, lastRatesUpdate: now);
      return true;
    }
    return false;
  }

  int convertToBase(int amount, String fromCurrency) {
    if (fromCurrency == state.baseCurrency) return amount;

    final rate = state.exchangeRates[fromCurrency];
    if (rate == null || rate == 0) return amount;
    return (amount / rate).round();
  }

  int convertAmount({
    required int amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return amount;

    final double inBase = fromCurrency == state.baseCurrency
        ? amount.toDouble()
        : amount / (state.exchangeRates[fromCurrency] ?? 1.0);

    final double result = toCurrency == state.baseCurrency
        ? inBase
        : inBase * (state.exchangeRates[toCurrency] ?? 1.0);

    return result.round();
  }

  // Оновлює дату успішного хмарного бекапу
  Future<void> updateCloudBackupTime() async {
    final now = DateTime.now();
    await ref
        .read(sharedPreferencesProvider)
        .setString('last_cloud_backup', now.toIso8601String());
    state = state.copyWith(lastCloudBackup: now);
  }

  // Оновлює дату успішного експорту у файл
  Future<void> updateFileBackupTime() async {
    final now = DateTime.now();
    await ref
        .read(sharedPreferencesProvider)
        .setString('last_file_backup', now.toIso8601String());
    state = state.copyWith(lastFileBackup: now);
  }
}
