import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../providers/all_providers.dart';
import '../../../theme/app_colors_extension.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/common/animated_dots.dart';
import '../../../widgets/bottom_sheets/stats_category_bottom_sheet.dart';

class MonthlyPieView extends ConsumerStatefulWidget {
  final AppColorsExtension colors;
  final String baseCurrencySymbol;
  final CategoryState catState;
  final TransactionState txState;
  final Color Function(String) getUniqueColor;
  final DateTime statsMonth;
  final bool showExpenses;
  final bool animatingForward;
  final Function(DateTime) onChangeMonth;

  const MonthlyPieView({
    super.key,
    required this.colors,
    required this.baseCurrencySymbol,
    required this.catState,
    required this.txState,
    required this.getUniqueColor,
    required this.statsMonth,
    required this.showExpenses,
    required this.animatingForward,
    required this.onChangeMonth,
  });

  @override
  ConsumerState<MonthlyPieView> createState() => _MonthlyPieViewState();
}

class _MonthlyPieViewState extends ConsumerState<MonthlyPieView> {
  int _touchedPieIndex = -1;
  bool _isBottomSheetOpen = false;
  double _dragStartX = 0.0;

  List<Category> _getSortedActiveCategories() {
    final allCategories = widget.catState.allCategoriesList;
    final Map<String, Category> categoryMap = {
      for (var c in allCategories) c.id: c,
    };

    final categoryTotals = ref
        .read(statsProvider.notifier)
        .calculateCategoryTotalsForMonth(
          widget.statsMonth,
          widget.showExpenses,
        );

    final List<Category> activeCategories = [];
    categoryTotals.forEach((categoryId, amountInBaseCurrency) {
      if (amountInBaseCurrency > 0 && categoryMap.containsKey(categoryId)) {
        activeCategories.add(
          categoryMap[categoryId]!.copyWith(amount: amountInBaseCurrency),
        );
      }
    });

    activeCategories.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    return activeCategories;
  }

  void _showCategoryTransactions(Category category) async {
    _isBottomSheetOpen = true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatsCategoryBottomSheet(
          category: category,
          statsMonth: widget.statsMonth,
          baseCurrencySymbol: widget.baseCurrencySymbol,
          showExpenses: widget.showExpenses,
        );
      },
    );

    _isBottomSheetOpen = false;

    if (mounted) {
      setState(() {
        _touchedPieIndex = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final activeData = _getSortedActiveCategories();
    final int activeTotal = activeData.fold(
      0,
      (sum, item) => sum + item.amount.abs().toInt(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (_dragStartX < 50.0 || _dragStartX > screenWidth - 50.0) return;

        const int sensitivity = 300;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -sensitivity) {
            widget.onChangeMonth(
              DateTime(widget.statsMonth.year, widget.statsMonth.month + 1, 1),
            );
          } else if (details.primaryVelocity! > sensitivity) {
            widget.onChangeMonth(
              DateTime(widget.statsMonth.year, widget.statsMonth.month - 1, 1),
            );
          }
        }
      },
      child: AnimatedSwitcher(
        // 👇 Зменшили тривалість, щоб уникнути накопичення контролерів при швидкому свайпі
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final inFrom = widget.animatingForward
              ? const Offset(1.0, 0.0)
              : const Offset(-1.0, 0.0);
          final outTo = widget.animatingForward
              ? const Offset(-1.0, 0.0)
              : const Offset(1.0, 0.0);

          // Оптимізація: використовуємо ключі для визначення напрямку
          final isEntering =
              child.key == ValueKey(widget.statsMonth.toIso8601String());

          return SlideTransition(
            position: Tween<Offset>(
              begin: isEntering ? inFrom : outTo,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: Container(
          // 👇 Цей ключ критично важливий для роботи AnimatedSwitcher
          key: ValueKey(widget.statsMonth.toIso8601String()),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.colors.cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: activeData.isEmpty
              ? Center(
                  child: Text(
                    widget.showExpenses
                        ? 'no_expenses_month'.tr()
                        : 'no_incomes_month'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.colors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      // 👇 Додано RepaintBoundary. Графік малюється окремо від списку. Це дуже економить пам'ять!
                      child: RepaintBoundary(
                        child: PieChart(
                          // 👇 Duration оптимізує внутрішні анімації fl_chart
                          duration: const Duration(milliseconds: 150),
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                // 👈 1. Якщо вікно відкрито — ігноруємо всі дотики до графіка
                                if (_isBottomSheetOpen) return;

                                // 2. Ловимо клік і відкриваємо історію
                                if (event is FlTapUpEvent &&
                                    _touchedPieIndex != -1) {
                                  final cat = activeData[_touchedPieIndex];
                                  _showCategoryTransactions(cat);
                                  return; // 👈 ВАЖЛИВО: виходимо, щоб не скинути індекс нижче
                                }

                                // 3. Звичайна поведінка при свайпі
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    _touchedPieIndex = -1;
                                    return;
                                  }

                                  _touchedPieIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                            ),
                            sectionsSpace: 2,
                            centerSpaceRadius: 38,
                            sections: activeData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final cat = entry.value;

                              final isTouched = index == _touchedPieIndex;
                              final value = cat.amount.abs() / 100.0;
                              final percentage =
                                  (value / (activeTotal / 100.0)) * 100;

                              final radius = isTouched ? 48.0 : 42.0;

                              return PieChartSectionData(
                                color: widget.getUniqueColor(cat.id),
                                value: value,
                                title: percentage >= 5.0
                                    ? '${percentage.toStringAsFixed(0)}%'
                                    : '',
                                radius: radius,
                                titlePositionPercentageOffset: 0.5,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 7,
                      child: ListView.builder(
                        // 👇 Додаємо ключі до елементів списку для оптимізації
                        itemCount: activeData.length,
                        itemBuilder: (context, index) {
                          final cat = activeData[index];
                          final percentage =
                              (cat.amount.abs() / activeTotal) * 100;
                          final rowColor = widget.getUniqueColor(cat.id);
                          final isTouched = index == _touchedPieIndex;

                          return InkWell(
                            // 👇 Ключ допомагає Flutter не перестворювати віджети списку
                            key: ValueKey(cat.id),
                            onTap: () {
                              setState(() => _touchedPieIndex = index);
                              _showCategoryTransactions(cat);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              // 👇 Зменшено час анімації підсвітки
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isTouched
                                    ? rowColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: rowColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      IconData(
                                        cat.icon,
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      size: 16,
                                      color: rowColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontWeight: isTouched
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontSize: 14,
                                        color: widget.colors.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: widget.colors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Stack(
                                    alignment: Alignment.centerRight,
                                    children: [
                                      Opacity(
                                        opacity: widget.txState.isMigrating
                                            ? 0.0
                                            : 1.0,
                                        child: Text(
                                          '${CurrencyFormatter.format(cat.amount.abs())} ${widget.baseCurrencySymbol}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: widget.colors.textMain,
                                          ),
                                        ),
                                      ),
                                      if (widget.txState.isMigrating)
                                        Positioned.fill(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: AnimatedDots(
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: widget.colors.textMain,
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
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
