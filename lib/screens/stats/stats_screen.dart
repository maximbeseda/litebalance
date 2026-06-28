import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/all_providers.dart';
import '../../models/app_currency.dart';
import '../../utils/amount_text.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/dialogs/month_picker_dialog.dart';
import '../../theme/app_colors_extension.dart';
import '../../widgets/common/animated_dots.dart';
import '../../widgets/common/pulsing_icon.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/rolling_digit.dart';

// Підключаємо наші ізольовані Views
import 'views/monthly_pie_view.dart';
import 'views/trends_chart_view.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _showExpenses = true;
  bool _showTrends = false;
  late DateTime _statsMonth;
  bool _animatingForward = true;
  DateTime _lastSwipeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _statsMonth = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(DateTime newMonth) {
    if (newMonth == _statsMonth) return;
    final now = DateTime.now();
    if (now.difference(_lastSwipeTime).inMilliseconds < 400) return;
    _lastSwipeTime = now;

    setState(() {
      _animatingForward = newMonth.isAfter(_statsMonth);
      _statsMonth = newMonth;
    });
  }

  final List<Color> _appCustomPalette = [
    const Color(0xFF2C3E50),
    const Color(0xFFE74C3C),
    const Color(0xFF27AE60),
    const Color(0xFF2980B9),
    const Color(0xFF8E44AD),
    const Color(0xFFF39C12),
    const Color(0xFF16A085),
    const Color(0xFFD35400),
    const Color(0xFF34495E),
    const Color(0xFFC0392B),
    const Color(0xFF1ABC9C),
    const Color(0xFF9B59B6),
    const Color(0xFFF1C40F),
    const Color(0xFFE67E22),
    const Color(0xFF3498DB),
    const Color(0xFF95A5A6),
    const Color(0xFF7F8C8D),
    const Color(0xFF2ECC71),
    const Color(0xFF4A6572),
    const Color(0xFF8D6E63),
    const Color(0xFF5D4037),
    const Color(0xFF009688),
    const Color(0xFF3F51B5),
    const Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final settingsState = ref.watch(settingsProvider);
    // 👇 Отримуємо стан як AsyncValue і витягуємо значення
    final txAsync = ref.watch(transactionProvider);
    final txState = txAsync.value;

    final catState = ref.watch(categoryProvider);

    // 👇 Показуємо лоадер, якщо дані ще не завантажились
    if (txAsync.isLoading || txState == null) {
      return Scaffold(
        backgroundColor: colors.bgGradientStart,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final isCurrentMonth =
        _statsMonth.year == now.year && _statsMonth.month == now.month;

    String displayCurrency;

    if (isCurrentMonth) {
      displayCurrency = settingsState.baseCurrency;
    } else {
      final monthTxs = txState.history.where(
        (tx) =>
            tx.date.year == _statsMonth.year &&
            tx.date.month == _statsMonth.month,
      );
      if (monthTxs.isNotEmpty) {
        displayCurrency = monthTxs.first.baseCurrency;
      } else {
        displayCurrency = settingsState.baseCurrency;
      }
    }

    final baseCurrencySymbol = AppCurrency.fromCode(displayCurrency).symbol;

    final sortedCatIds =
        catState.allCategoriesList
            .where(
              (c) =>
                  c.type == CategoryType.expense ||
                  c.type == CategoryType.income,
            )
            .map((e) => e.id)
            .toList()
          ..sort();

    Color getUniqueColor(String id) {
      int index = sortedCatIds.indexOf(id);
      if (index == -1) index = 0;
      return _appCustomPalette[index % _appCustomPalette.length];
    }

    return Scaffold(
      backgroundColor: _showTrends ? colors.cardBg : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _showTrends ? colors.cardBg : null,
          gradient: _showTrends
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.bgGradientStart, colors.bgGradientEnd],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(colors),
              if (!_showTrends) ...[
                _buildMonthSelector(colors),
                _buildTotalsToggle(colors, baseCurrencySymbol, txState),
              ],
              Expanded(
                child: _showTrends
                    ? _buildTrendsView(colors)
                    : MonthlyPieView(
                        colors: colors,
                        baseCurrencySymbol: baseCurrencySymbol,
                        catState: catState,
                        // 👇 Передаємо вже розпакований txState
                        txState: txState,
                        getUniqueColor: getUniqueColor,
                        statsMonth: _statsMonth,
                        showExpenses: _showExpenses,
                        animatingForward: _animatingForward,
                        onChangeMonth: _changeMonth,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0, right: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'statistics'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: PulsingIcon(
              icon: _showTrends ? Icons.pie_chart_outline : Icons.auto_graph,
              color: colors.textMain,
              size: 24,
            ),
            onPressed: () => setState(() => _showTrends = !_showTrends),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colors.textMain),
            onPressed: () => _changeMonth(
              DateTime(_statsMonth.year, _statsMonth.month - 1, 1),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final pickedDate = await showDialog<DateTime>(
                context: context,
                builder: (ctx) => MonthPickerDialog(initialDate: _statsMonth),
              );
              if (pickedDate != null && mounted) _changeMonth(pickedDate);
            },
            child: Container(
              constraints: BoxConstraints(
                minWidth: 130,
                maxWidth: MediaQuery.of(context).size.width * 0.45,
              ),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormatter.formatMonthYear(
                    _statsMonth,
                    context.locale.languageCode,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: colors.textMain),
            onPressed: () => _changeMonth(
              DateTime(_statsMonth.year, _statsMonth.month + 1, 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsToggle(
    AppColorsExtension colors,
    String baseCurrencySymbol,
    TransactionState txState, // Отримуємо вже готовий стейт
  ) {
    final allMonthTotals = ref
        .read(statsProvider.notifier)
        .calculateTotalsForMonth(_statsMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: !_showExpenses
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _toggleItem(
                  'income'.tr(),
                  (allMonthTotals['incomes'] ?? 0).toInt(),
                  !txState.isMigrating,
                  !_showExpenses,
                  colors.income,
                  baseCurrencySymbol,
                  () {
                    setState(() {
                      _showExpenses = false;
                    });
                  },
                  colors,
                ),
                _toggleItem(
                  'stats_expenses'.tr(),
                  (allMonthTotals['expenses'] ?? 0).toInt(),
                  !txState.isMigrating,
                  _showExpenses,
                  colors.expense,
                  baseCurrencySymbol,
                  () {
                    setState(() {
                      _showExpenses = true;
                    });
                  },
                  colors,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(
    String label,
    int amount,
    bool isReady,
    bool isActive,
    Color activeColor,
    String symbol,
    VoidCallback onTap,
    AppColorsExtension colors,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? colors.textMain : colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: isReady ? 1.0 : 0.0,
                  child: _buildRollingAmount(
                    amount,
                    symbol,
                    TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isActive
                          ? activeColor
                          : colors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (!isReady)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: AnimatedDots(
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isActive
                              ? activeColor
                              : colors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Сума з ефектом "слот-машини" (кожна цифра плавно прокручується).
  Widget _buildRollingAmount(int amount, String symbol, TextStyle style) {
    final formatted = CurrencyFormatter.format(amount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      // Цифри суми — окремі віджети в Row; у RTL-локалях Row реверсує дітей,
      // тож фіксуємо порядок зліва направо.
      textDirection: ui.TextDirection.ltr,
      children: [
        for (int i = 0; i < formatted.length; i++)
          RollingDigit(char: formatted[i], style: style),
        Text(' ${symbol.trim()}', style: CurrencyAmount.symbolStyle(style)),
      ],
    );
  }

  Widget _buildTrendsView(AppColorsExtension colors) {
    final trends = ref.read(statsProvider.notifier).calculateTrends();
    if (trends.isEmpty) {
      return AppEmptyState(
        icon: Icons.show_chart_rounded,
        title: 'no_data'.tr(),
        subtitle: 'no_data_hint'.tr(),
        animate: false,
      );
    }
    return TrendsChartView(
      trends: trends,
      colors: colors,
      showExpenses: _showExpenses,
    );
  }
}
