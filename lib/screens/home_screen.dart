import 'dart:async';
import 'package:litebalance/theme/category_defaults.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:collection/collection.dart';

import '../widgets/bottom_sheets/history_bottom_sheet.dart';
import '../widgets/common/summary_header.dart';
import '../widgets/bottom_sheets/general_history_bottom_sheet.dart';
import '../widgets/common/settings_drawer.dart';
import '../widgets/common/home_screen_skeleton.dart';
import '../screens/transaction_screen.dart';
import '../screens/category_screen.dart';
import '../widgets/dialogs/due_subscription_dialog.dart';
import '../utils/currency_formatter.dart';
import '../theme/app_colors_extension.dart';
import '../providers/all_providers.dart';

// 👇 НОВИЙ ІМПОРТ НАШОЇ СЕКЦІЇ
import '../widgets/home/category_section.dart';
import '../widgets/home/home_tutorial.dart';

String formatCurrency(int amount) => CurrencyFormatter.format(amount);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isShowingDueDialog = false;

  // Ключі-цілі для покрокової підказки (coach marks) при першому запуску.
  final GlobalKey _tutHeaderKey = GlobalKey();
  final GlobalKey _tutIncomeKey = GlobalKey();
  final GlobalKey _tutAccountKey = GlobalKey();
  final GlobalKey _tutMenuKey = GlobalKey();
  bool _tutorialScheduled = false;
  Timer? _tutorialTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDueSubscriptions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        ref.read(subscriptionProvider.notifier).refreshOnAppResume();
        // Якщо додаток провисів у фоні через межу місяця — оновлюємо місяць,
        // щоб суми доходів/витрат обнулилися без повного перезапуску.
        ref.read(transactionProvider.notifier).syncSelectedMonthToCurrent();
      }
    }
  }

  void _checkDueSubscriptions() {
    if (!mounted) return;
    // 👇 ВИПРАВЛЕНО: розпаковуємо AsyncValue
    final subAsync = ref.read(subscriptionProvider);
    final subState = subAsync.value;

    if (subState != null &&
        subState.dueSubscriptions.isNotEmpty &&
        !_isShowingDueDialog) {
      _showDueSubscriptionDialog(subState.dueSubscriptions.first);
    }
  }

  void _showDueSubscriptionDialog(Subscription sub) {
    if (_isShowingDueDialog) return;
    _isShowingDueDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DueSubscriptionDialog(subscription: sub),
    ).then((_) {
      _isShowingDueDialog = false;
    });
  }

  @override
  void dispose() {
    _tutorialTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Одноразово (за перший вхід на головний екран) запускає покрокову підказку.
  /// Викликається з build() лише коли реальний контент уже готовий рендеритись,
  /// тож ключі-цілі гарантовано мають розмір.
  void _maybeScheduleTutorial() {
    if (_tutorialScheduled) return;
    _tutorialScheduled = true;

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getBool('has_seen_home_tutorial') ?? false) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Невелика пауза, щоб анімації входу відпрацювали й layout устоявся.
        // Таймер скасовується в dispose(), щоб не «висів» після виходу з екрана.
        _tutorialTimer = Timer(const Duration(milliseconds: 550), () {
          if (!mounted || _isShowingDueDialog) return;
          HomeTutorial.build(
            context: context,
            headerKey: _tutHeaderKey,
            incomeKey: _tutIncomeKey,
            accountKey: _tutAccountKey,
            menuKey: _tutMenuKey,
            onDone: () => prefs.setBool('has_seen_home_tutorial', true),
          ).show(context: context);
        });
      });
    } catch (_) {
      // Напр. у тестах без override sharedPreferencesProvider — тур пропускаємо.
    }
  }

  Future<void> _handleTransfer(Category source, Category target) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TransactionScreen(source: source, target: target),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

    if (!mounted || result == null) return;

    final amount = result['amount'] as int;
    final targetAmount = result['targetAmount'] as int?;
    final date = result['date'] as DateTime;
    final comment = result['comment'] as String;

    if (amount > 0) {
      final txNotifier = ref.read(transactionProvider.notifier);
      final settingsNotifier = ref.read(settingsProvider.notifier);
      final settingsState = ref.read(settingsProvider);

      final String txTitle = comment.trim().isNotEmpty
          ? comment.trim()
          : '${'transfer'.tr()} ${source.name} ➡️ ${target.name}';

      final int baseAmt = settingsNotifier.convertToBase(
        amount,
        source.currency,
      );

      final newTx = Transaction(
        id: const Uuid().v4(),
        fromId: source.id,
        toId: target.id,
        title: txTitle,
        amount: amount,
        date: date,
        currency: source.currency,
        targetAmount: targetAmount,
        targetCurrency: source.currency != target.currency
            ? target.currency
            : null,
        baseAmount: baseAmt,
        baseCurrency: settingsState.baseCurrency,
      );

      await txNotifier.addTransactionDirectly(newTx);
    }
  }

  Future<void> _handleEditTransaction(
    Transaction t,
    List<Category> allCategories,
  ) async {
    final Category? sourceCat = allCategories.firstWhereOrNull(
      (c) => c.id == t.fromId,
    );
    final Category? targetCat = allCategories.firstWhereOrNull(
      (c) => c.id == t.toId,
    );

    if (sourceCat == null || targetCat == null) return;

    final String initialNote = t.title.contains('➡️') ? '' : t.title;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TransactionScreen(
              source: sourceCat,
              target: targetCat,
              initialAmount: t.amount,
              initialTargetAmount: t.targetAmount,
              initialDate: t.date,
              initialNote: initialNote,
              initialSourceCurrency: t.currency,
              initialTargetCurrency: t.targetCurrency ?? t.currency,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

    if (!mounted || result == null) return;

    final txNotifier = ref.read(transactionProvider.notifier);
    final comment = result['comment'] as String;

    final newTitle = comment.trim().isNotEmpty
        ? comment.trim()
        : '${'transfer'.tr()} ${sourceCat.name} ➡️ ${targetCat.name}';

    final updatedT = t.copyWith(title: newTitle);

    await txNotifier.editTransaction(
      updatedT,
      result['amount'],
      result['date'],
      newTargetAmount: result['targetAmount'],
    );
  }

  Future<dynamic> _showCategoryDialog({
    Category? c,
    required CategoryType type,
  }) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CategoryScreen(category: c, type: type),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

    if (ref.read(homeScreenControllerProvider).isEditMode && mounted) {
      ref.read(homeScreenControllerProvider.notifier).toggleEditMode();
    }

    if (!mounted || result == null) return null;

    if (result == 'delete') return 'delete';

    final catNotifier = ref.read(categoryProvider.notifier);

    if (result is Map) {
      if (c == null) {
        final prefix = type == CategoryType.income
            ? 'inc'
            : (type == CategoryType.account ? 'acc' : 'exp');
        final n = Category(
          id: '${prefix}_${const Uuid().v4()}',
          type: type,
          name: result['name'],
          icon: result['icon'],
          amount: (result['amount'] as num?)?.toInt() ?? 0,
          budget: (result['budget'] as num?)?.toInt(),
          isArchived: false,
          bgColor: CategoryDefaults.getBgColor(type).toARGB32(),
          iconColor: CategoryDefaults.getIconColor(type).toARGB32(),
          currency:
              result['currency'] ?? ref.read(settingsProvider).baseCurrency,
          includeInTotal: result['includeInTotal'] ?? true,
          sortOrder: 0,
        );
        await catNotifier.addOrUpdateCategory(n);
      } else {
        final updatedCategory = c.copyWith(
          name: result['name'],
          icon: result['icon'],
          budget: drift.Value(result['budget']),
          amount: type == CategoryType.account
              ? (result['amount'] ?? c.amount)
              : c.amount,
          currency: result['currency'] ?? c.currency,
          includeInTotal: result['includeInTotal'] ?? c.includeInTotal,
        );
        await catNotifier.addOrUpdateCategory(updatedCategory);
      }
    }
    return result;
  }

  void _openGeneralHistoryBottomSheet(
    BuildContext context,
    String title,
    CategoryType type,
  ) {
    final txState = ref.read(transactionProvider).value;
    if (txState == null) return;
    final catState = ref.read(categoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GeneralHistoryBottomSheet(
        title: title,
        filterType: type,
        transactions: txState.history,
        allCategories: catState.allCategoriesList,
        onDelete: (t) async =>
            await ref.read(transactionProvider.notifier).moveToTrash(t),
        onEdit: (t) => _handleEditTransaction(t, catState.allCategoriesList),
      ),
    );
  }

  void _openCategoryHistory(Category c) {
    final catState = ref.read(categoryProvider);
    final txState = ref.read(transactionProvider).value;
    if (txState == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistoryBottomSheet(
        category: c,
        transactions: txState.history,
        allCategories: catState.allCategoriesList,
        onDelete: (t) async =>
            await ref.read(transactionProvider.notifier).moveToTrash(t),
        onEdit: (t) => _handleEditTransaction(t, catState.allCategoriesList),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final homeState = ref.watch(homeScreenControllerProvider);
    final homeNotifier = ref.read(homeScreenControllerProvider.notifier);
    final catState = ref.watch(categoryProvider);
    final txAsync = ref.watch(transactionProvider);
    final txState = txAsync.value;

    final settingsState = ref.watch(settingsProvider);
    final statsNotifier = ref.read(statsProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // 👇 ВИПРАВЛЕНО: розпаковуємо AsyncValue у лісенері
    ref.listen(subscriptionProvider, (prev, next) {
      final nextState = next.value;
      if (nextState != null &&
          nextState.dueSubscriptions.isNotEmpty &&
          !_isShowingDueDialog) {
        _showDueSubscriptionDialog(nextState.dueSubscriptions.first);
      }
    });

    // Показуємо скелетон тільки якщо даних ВЗАГАЛІ немає.
    // Якщо дані вже є (наприклад, під час фонової синхронізації), ми ігноруємо isLoading.
    final hasCategories =
        catState.incomes.isNotEmpty ||
        catState.accounts.isNotEmpty ||
        catState.expenses.isNotEmpty;

    if ((catState.isLoading && !hasCategories) ||
        (txAsync.isLoading && !txAsync.hasValue) ||
        txState == null) {
      return Scaffold(
        backgroundColor: colors.bgGradientStart,
        body: const HomeScreenSkeleton(),
      );
    }

    final monthTotals = statsNotifier.calculateTotalsForMonth(
      txState.selectedMonth,
    );
    final int totalIncomes = monthTotals['incomes'] ?? 0;
    final int totalExpenses = monthTotals['expenses'] ?? 0;

    final int totalBalance = catState.accounts
        .where((item) => item.includeInTotal)
        .fold(
          0,
          (sum, item) =>
              sum + settingsNotifier.convertToBase(item.amount, item.currency),
        );

    final baseIncomeMap = statsNotifier.calculateCategoryTotalsForMonth(
      txState.selectedMonth,
      false,
      inBaseCurrency: true,
    );
    final rawIncomeMap = statsNotifier.calculateCategoryTotalsForMonth(
      txState.selectedMonth,
      false,
      inBaseCurrency: false,
    );

    final displayIncomes = catState.incomes.map((c) {
      final bool isBase = c.currency == settingsState.baseCurrency;
      return c.copyWith(
        amount: isBase ? (baseIncomeMap[c.id] ?? 0) : (rawIncomeMap[c.id] ?? 0),
      );
    }).toList();

    final baseExpenseMap = statsNotifier.calculateCategoryTotalsForMonth(
      txState.selectedMonth,
      true,
      inBaseCurrency: true,
    );
    final rawExpenseMap = statsNotifier.calculateCategoryTotalsForMonth(
      txState.selectedMonth,
      true,
      inBaseCurrency: false,
    );

    final displayExpenses = catState.expenses.map((c) {
      final bool isBase = c.currency == settingsState.baseCurrency;
      return c.copyWith(
        amount: isBase
            ? (baseExpenseMap[c.id] ?? 0)
            : (rawExpenseMap[c.id] ?? 0),
      );
    }).toList();

    // Реальний контент готовий — можна показати покрокову підказку (одноразово).
    _maybeScheduleTutorial();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const SettingsDrawer(),
      // Відкриваємо лише кнопкою: edge-свайп drawer'а конфліктував із системним
      // жестом «назад» і давав білий проблиск збоку.
      endDrawerEnableOpenDragGesture: false,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (homeState.isEditMode) homeNotifier.toggleEditMode();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.bgGradientStart, colors.bgGradientEnd],
            ),
          ),
          child: SafeArea(
            maintainBottomViewPadding: true,
            child: Column(
              children: [
                SummaryHeader(
                  key: _tutHeaderKey,
                  settingsKey: _tutMenuKey,
                  totalBalance: totalBalance,
                  totalIncomes: totalIncomes,
                  totalExpenses: totalExpenses,
                  isMigrating: txState.isMigrating,
                  onBalanceTap: () {
                    if (homeState.isEditMode) {
                      homeNotifier.toggleEditMode();
                      return;
                    }
                    _openGeneralHistoryBottomSheet(
                      context,
                      'history_balance'.tr(),
                      CategoryType.account,
                    );
                  },
                  onIncomesTap: () {
                    if (homeState.isEditMode) {
                      homeNotifier.toggleEditMode();
                      return;
                    }
                    _openGeneralHistoryBottomSheet(
                      context,
                      'history_incomes'.tr(),
                      CategoryType.income,
                    );
                  },
                  onExpensesTap: () {
                    if (homeState.isEditMode) {
                      homeNotifier.toggleEditMode();
                      return;
                    }
                    _openGeneralHistoryBottomSheet(
                      context,
                      'history_expenses'.tr(),
                      CategoryType.expense,
                    );
                  },
                  onSettingsTap: () {
                    if (homeState.isEditMode) {
                      homeNotifier.toggleEditMode();
                      return;
                    }
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),

                CategorySection(
                  key: _tutIncomeKey,
                  categories: displayIncomes,
                  type: CategoryType.income,
                  onTransfer: _handleTransfer,
                  onHistoryTap: _openCategoryHistory,
                  onEditTap: (c) => _showCategoryDialog(c: c, type: c.type),
                  onAddTap: () =>
                      _showCategoryDialog(type: CategoryType.income),
                ),

                CategorySection(
                  key: _tutAccountKey,
                  categories: catState.accounts,
                  type: CategoryType.account,
                  isTarget: true,
                  onTransfer: _handleTransfer,
                  onHistoryTap: _openCategoryHistory,
                  onEditTap: (c) => _showCategoryDialog(c: c, type: c.type),
                  onAddTap: () =>
                      _showCategoryDialog(type: CategoryType.account),
                ),

                Expanded(
                  child: CategorySection(
                    categories: displayExpenses,
                    type: CategoryType.expense,
                    isTarget: true,
                    isGrid: true,
                    onTransfer: _handleTransfer,
                    onHistoryTap: _openCategoryHistory,
                    onEditTap: (c) => _showCategoryDialog(c: c, type: c.type),
                    onAddTap: () =>
                        _showCategoryDialog(type: CategoryType.expense),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
