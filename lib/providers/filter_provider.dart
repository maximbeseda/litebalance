import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import 'all_providers.dart';

part 'filter_provider.g.dart';

class FilterState {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final CategoryType? selectedType;
  final String? selectedCurrency;
  final String? specificCategoryId;

  final List<Transaction> results;
  final bool isLoading;

  // ДОДАНО ДЛЯ ПАГІНАЦІЇ
  final int currentPage;
  final bool hasMore;

  FilterState({
    this.searchQuery = '',
    this.startDate,
    this.endDate,
    this.selectedType,
    this.selectedCurrency,
    this.specificCategoryId,
    this.results = const [],
    this.isLoading = false,
    this.currentPage = 0,
    this.hasMore = true,
  });

  FilterState copyWith({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    CategoryType? selectedType,
    String? selectedCurrency,
    String? specificCategoryId,
    List<Transaction>? results,
    bool? isLoading,
    int? currentPage,
    bool? hasMore,
    bool clearDates = false,
    bool clearType = false,
    bool clearCurrency = false,
  }) {
    return FilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      selectedCurrency: clearCurrency
          ? null
          : (selectedCurrency ?? this.selectedCurrency),
      specificCategoryId: specificCategoryId ?? this.specificCategoryId,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

@riverpod
class FilterNotifier extends _$FilterNotifier {
  static const int _pageSize = 30; // Скільки вантажимо за раз

  // Таймер для затримки виконання запиту до БД (Debouncing)
  Timer? _debounceTimer;

  @override
  FilterState build() {
    // Очищаємо таймер при знищенні провайдера, щоб уникнути витоку пам'яті
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // 👇 МАГІЯ: Якщо ти видалив або відредагував транзакцію в UI,
    // FilterProvider миттєво це помітить і оновить список!
    ref.listen(transactionProvider, (prevAsync, nextAsync) {
      // ВИПРАВЛЕНО: Використовуємо просто .value замість .valueOrNull
      final prev = prevAsync?.value;
      final next = nextAsync.value;

      if (prev != null && next != null && prev.history != next.history) {
        _applyFilters();
      }
    });

    return FilterState();
  }

  void initForCategory(String categoryId) {
    state = FilterState(specificCategoryId: categoryId);
    _applyFilters();
  }

  void initGeneral() {
    state = FilterState();
    _applyFilters();
  }

  void setSearchQuery(String query) {
    // 1. Оновлюємо стан миттєво для плавного UI
    state = state.copyWith(searchQuery: query);

    // 2. Скасовуємо попередній таймер, якщо користувач продовжує друкувати
    _debounceTimer?.cancel();

    // 3. Запускаємо новий таймер
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters(); // Звернення до БД лише після паузи
    });
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      clearDates: start == null && end == null,
    );
    _applyFilters();
  }

  void setCategoryType(CategoryType? type) {
    state = state.copyWith(selectedType: type, clearType: type == null);
    _applyFilters();
  }

  void setCurrency(String? currency) {
    state = state.copyWith(
      selectedCurrency: currency,
      clearCurrency: currency == null,
    );
    _applyFilters();
  }

  void clearAllFilters() {
    state = FilterState(specificCategoryId: state.specificCategoryId);
    _applyFilters();
  }

  // НОВИЙ МЕТОД ДЛЯ ПАГІНАЦІЇ (Викликається при скролі вниз)
  Future<void> loadNextPage() async {
    // Якщо більше немає даних, або вже вантажимо — ігноруємо
    if (!state.hasMore || state.isLoading) {
      return;
    }
    await _applyFilters(loadMore: true);
  }

  Future<void> _applyFilters({bool loadMore = false}) async {
    if (!loadMore) {
      state = state.copyWith(
        isLoading: true,
        currentPage: 0,
        hasMore: true,
        results: [],
      );
    }

    final db = ref.read(appDatabaseProvider);
    final catState = ref.read(categoryProvider);

    // 1. ГОТУЄМО СУВОРІ ФІЛЬТРИ ДЛЯ SQL
    List<String>? filterCategoryIds;
    if (state.specificCategoryId != null) {
      filterCategoryIds = [state.specificCategoryId!];
    } else if (state.selectedType != null) {
      filterCategoryIds = catState.allCategoriesList
          .where((c) => c.type == state.selectedType)
          .map((c) => c.id)
          .toList();
      if (filterCategoryIds.isEmpty) filterCategoryIds = ['__empty__'];
    }

    // 2. ВИЗНАЧАЄМО ЛІМІТ ТА ОФСЕТ ДЛЯ SQL
    // Пагінація тепер працює завжди, навіть під час пошуку!
    const limit = _pageSize;
    final offset = state.currentPage * _pageSize;

    // Коли користувач вводить текст для пошуку, логічно шукати по всій історії (ігноруючи дати)
    final isSearching = state.searchQuery.isNotEmpty;

    // 3. ОТРИМУЄМО ПОРЦІЮ З БАЗИ ДАНИХ (Блискавично)
    final newBatch = await db.getFilteredTransactions(
      startDate: isSearching ? null : state.startDate,
      endDate: isSearching ? null : state.endDate,
      filterCategoryIds: filterCategoryIds,
      currency: state.selectedCurrency,
      limit: limit,
      offset: offset,
      searchQuery: isSearching ? state.searchQuery : null,
    );

    if (!ref.mounted) return;

    // 4. ЗБЕРІГАЄМО ПАГІНОВАНІ ДАНІ (Пошук вже зроблено в SQL)
    state = state.copyWith(
      results: loadMore ? [...state.results, ...newBatch] : newBatch,
      isLoading: false,
      hasMore: newBatch.length == _pageSize,
      currentPage: state.currentPage + 1,
    );
  }
}
