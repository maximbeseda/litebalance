import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart' as drift;

import '../services/storage_service.dart';
import 'all_providers.dart';

part 'category_provider.g.dart';

// 1. СТАН (State)
class CategoryState {
  final List<Category> incomes;
  final List<Category> accounts;
  final List<Category> expenses;
  final List<Category> archivedCategories;
  final List<Category> deletedCategories;
  final bool isLoading;

  CategoryState({
    required this.incomes,
    required this.accounts,
    required this.expenses,
    required this.archivedCategories,
    required this.deletedCategories,
    required this.isLoading,
  });

  CategoryState copyWith({
    List<Category>? incomes,
    List<Category>? accounts,
    List<Category>? expenses,
    List<Category>? archivedCategories,
    List<Category>? deletedCategories,
    bool? isLoading,
  }) {
    return CategoryState(
      incomes: incomes ?? this.incomes,
      accounts: accounts ?? this.accounts,
      expenses: expenses ?? this.expenses,
      archivedCategories: archivedCategories ?? this.archivedCategories,
      deletedCategories: deletedCategories ?? this.deletedCategories,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<Category> get allCategoriesList => [
    ...incomes,
    ...accounts,
    ...expenses,
    ...archivedCategories,
    ...deletedCategories, // Включаємо кошик у загальний список для безпеки
  ];
}

// 2. СУЧАСНИЙ NOTIFIER
@Riverpod(keepAlive: true)
class CategoryNotifier extends _$CategoryNotifier {
  @override
  CategoryState build() {
    final initialState = CategoryState(
      incomes: [],
      accounts: [],
      expenses: [],
      archivedCategories: [],
      deletedCategories: [],
      isLoading: true,
    );

    Future.microtask(() => loadCategories());

    return initialState;
  }

  Future<void> loadCategories() async {
    // 👇 ЗАХИСТ ВІД КРЕШУ: Якщо зараз іде підміна файлу бази з хмари — не ліземо туди!
    // Провайдер просто зачекає, поки backup_service сам його викличе після розпакування.
    if (ref.read(syncControllerProvider).isSyncing) return;

    final db = ref.read(appDatabaseProvider);

    // Асинхронний запит до БД
    final savedCats = await StorageService.loadCategories(db);

    // 👇 КРИТИЧНО ДЛЯ PRODUCTION: Перевіряємо, чи провайдер ще існує
    // Якщо користувач пішов з екрану або тест завершився — зупиняємо виконання
    if (!ref.mounted) return;

    List<Category> newIncomes = [];
    List<Category> newAccounts = [];
    List<Category> newExpenses = [];
    List<Category> newArchived = [];
    List<Category> newDeleted = [];

    if (savedCats.isNotEmpty) {
      final sorted = List<Category>.from(savedCats)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      newDeleted = sorted.where((c) => c.deletedAt != null).toList();
      final notDeleted = sorted.where((c) => c.deletedAt == null).toList();

      newIncomes = notDeleted
          .where((c) => c.type == CategoryType.income && !c.isArchived)
          .toList();
      newAccounts = notDeleted
          .where((c) => c.type == CategoryType.account && !c.isArchived)
          .toList();
      newExpenses = notDeleted
          .where((c) => c.type == CategoryType.expense && !c.isArchived)
          .toList();
      newArchived = notDeleted.where((c) => c.isArchived).toList();
    }

    state = state.copyWith(
      incomes: newIncomes,
      accounts: newAccounts,
      expenses: newExpenses,
      archivedCategories: newArchived,
      deletedCategories: newDeleted,
      isLoading: false,
    );
  }

  void updateCategoryAmount(String id, int delta) {
    final db = ref.read(appDatabaseProvider);
    final all = state.allCategoriesList;
    final index = all.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final category = all[index];
    final updatedCategory = category.copyWith(amount: category.amount + delta);

    if (updatedCategory.type == CategoryType.income) {
      final newList = List<Category>.from(state.incomes);
      final int idx = newList.indexWhere((c) => c.id == id);
      if (idx != -1) newList[idx] = updatedCategory;
      state = state.copyWith(incomes: newList);
    } else if (updatedCategory.type == CategoryType.account) {
      final newList = List<Category>.from(state.accounts);
      final int idx = newList.indexWhere((c) => c.id == id);
      if (idx != -1) newList[idx] = updatedCategory;
      state = state.copyWith(accounts: newList);
    } else {
      final newList = List<Category>.from(state.expenses);
      final int idx = newList.indexWhere((c) => c.id == id);
      if (idx != -1) newList[idx] = updatedCategory;
      state = state.copyWith(expenses: newList);
    }

    StorageService.saveCategory(db, updatedCategory);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }

  Future<void> addOrUpdateCategory(Category cat) async {
    final db = ref.read(appDatabaseProvider);
    List<Category> targetList;

    if (cat.type == CategoryType.income) {
      targetList = List<Category>.from(state.incomes);
    } else if (cat.type == CategoryType.account) {
      targetList = List<Category>.from(state.accounts);
    } else {
      targetList = List<Category>.from(state.expenses);
    }

    final int index = targetList.indexWhere((c) => c.id == cat.id);
    if (index == -1) {
      final newCat = cat.copyWith(sortOrder: targetList.length);
      targetList.add(newCat);
      await StorageService.saveCategory(db, newCat);
    } else {
      targetList[index] = cat;
      await StorageService.saveCategory(db, cat);
    }

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    if (cat.type == CategoryType.income) {
      state = state.copyWith(incomes: targetList);
    } else if (cat.type == CategoryType.account) {
      state = state.copyWith(accounts: targetList);
    } else {
      state = state.copyWith(expenses: targetList);
    }
  }

  // ==========================================
  // 👇 НОВА ЛОГІКА КОШИКА ТА ВИДАЛЕННЯ
  // ==========================================

  // 1. Перемістити в кошик (Soft Delete)
  Future<void> moveToTrash(Category cat) async {
    final db = ref.read(appDatabaseProvider);

    // Ставимо поточну дату як дату видалення. Використовуємо drift.Value
    final deletedCat = cat.copyWith(deletedAt: drift.Value(DateTime.now()));
    await StorageService.saveCategory(db, deletedCat);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    // Просто перезавантажуємо стан, щоб списки правильно розклалися
    await loadCategories();
  }

  // 2. Відновити з кошика
  Future<void> restoreFromTrash(Category cat) async {
    final db = ref.read(appDatabaseProvider);

    // Скидаємо deletedAt. Для Drift null передається як const drift.Value(null)
    final restoredCat = cat.copyWith(deletedAt: const drift.Value(null));
    await StorageService.saveCategory(db, restoredCat);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    await loadCategories();
  }

  // 3. Остаточне видалення або Архівація
  Future<void> emptyTrashOrArchive(Category cat) async {
    // 1. Використовуємо уніфікований провайдер
    final db = ref.read(appDatabaseProvider);

    // 2. Більш легкий запит для SQLite: шукаємо один запис або null
    final transaction =
        await (db.select(db.transactions)
              ..where((t) => t.fromId.equals(cat.id) | t.toId.equals(cat.id))
              ..limit(1))
            .getSingleOrNull();

    // Перевіряємо наявність через null-check
    if (transaction != null) {
      // 🔴 Є транзакції: Архівуємо (Soft Delete recovery)
      final archivedCat = cat.copyWith(
        deletedAt: const drift.Value(null),
        isArchived: true,
      );
      await StorageService.saveCategory(db, archivedCat);
    } else {
      // 🟢 Транзакцій немає: Видаляємо фізично (Hard Delete)
      await (db.delete(db.categories)..where((c) => c.id.equals(cat.id))).go();
    }

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    // 3. Оновлюємо UI
    await loadCategories();
  }

  // ==========================================

  void reorderCategories(Category dragged, Category target) {
    final db = ref.read(appDatabaseProvider);
    if (dragged.type != target.type) return;

    final List<Category> targetList = List<Category>.from(
      dragged.type == CategoryType.income
          ? state.incomes
          : dragged.type == CategoryType.account
          ? state.accounts
          : state.expenses,
    );

    final int oldIndex = targetList.indexWhere((c) => c.id == dragged.id);
    final int newIndex = targetList.indexWhere((c) => c.id == target.id);

    if (oldIndex != -1 && newIndex != -1 && oldIndex != newIndex) {
      final item = targetList.removeAt(oldIndex);
      targetList.insert(newIndex, item);

      for (int i = 0; i < targetList.length; i++) {
        targetList[i] = targetList[i].copyWith(sortOrder: i);
      }

      StorageService.saveCategories(db, targetList);

      // 👇 ДОДАНО: Ставимо прапорець бекапу
      ref.read(dbDirtyProvider.notifier).setDirty(true);

      if (dragged.type == CategoryType.income) {
        state = state.copyWith(incomes: targetList);
      } else if (dragged.type == CategoryType.account) {
        state = state.copyWith(accounts: targetList);
      } else {
        state = state.copyWith(expenses: targetList);
      }
    }
  }

  Future<void> updateBaseCurrencyForCategories(
    String oldBase,
    String newBase,
  ) async {
    final db = ref.read(appDatabaseProvider);

    final newIncomes = state.incomes.map((c) {
      if (c.currency == oldBase) return c.copyWith(currency: newBase);
      return c;
    }).toList();

    final newExpenses = state.expenses.map((c) {
      if (c.currency == oldBase) return c.copyWith(currency: newBase);
      return c;
    }).toList();

    await StorageService.saveCategories(db, [
      ...newIncomes,
      ...state.accounts,
      ...newExpenses,
      ...state.archivedCategories,
      ...state.deletedCategories, // Захоплюємо і кошик теж!
    ]);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);

    state = state.copyWith(incomes: newIncomes, expenses: newExpenses);
  }

  Future<void> resetAllBalances() async {
    final db = ref.read(appDatabaseProvider);

    final newIncomes = state.incomes.map((c) => c.copyWith(amount: 0)).toList();
    final newAccounts = state.accounts
        .map((c) => c.copyWith(amount: 0))
        .toList();
    final newExpenses = state.expenses
        .map((c) => c.copyWith(amount: 0))
        .toList();
    final newArchived = state.archivedCategories
        .map((c) => c.copyWith(amount: 0))
        .toList();
    final newDeleted = state.deletedCategories
        .map((c) => c.copyWith(amount: 0))
        .toList();

    state = state.copyWith(
      incomes: newIncomes,
      accounts: newAccounts,
      expenses: newExpenses,
      archivedCategories: newArchived,
      deletedCategories: newDeleted,
    );

    await StorageService.saveCategories(db, state.allCategoriesList);

    // 👇 ДОДАНО: Ставимо прапорець бекапу
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }
}
