import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../models/app_currency.dart';
import '../../../utils/currency_formatter.dart';
import '../../../theme/app_colors_extension.dart';
import '../../../widgets/bottom_sheets/stats_month_bottom_sheet.dart';
import '../../../widgets/common/pulsing_icon.dart';
import '../../../widgets/common/app_empty_state.dart';
import '../../../utils/app_page_route.dart';
import '../year_summary_screen.dart';

class TrendsChartView extends StatefulWidget {
  final Map<String, Map<String, Map<String, int>>> trends;
  final AppColorsExtension colors;
  final bool showExpenses;

  const TrendsChartView({
    super.key,
    required this.trends,
    required this.colors,
    required this.showExpenses,
  });

  @override
  State<TrendsChartView> createState() => _TrendsChartViewState();
}

class _TrendsChartViewState extends State<TrendsChartView> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.trends.isNotEmpty ? widget.trends.length - 1 : 0;
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.trends.keys.toList();
    if (keys.isEmpty) {
      return AppEmptyState(
        icon: Icons.show_chart_rounded,
        title: 'no_data'.tr(),
        subtitle: 'no_data_hint'.tr(),
        animate: false,
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            itemCount: keys.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _TrendCardWidget(
                currency: keys[index],
                data: widget.trends[keys[index]]!,
                colors: widget.colors,
                showExpenses: widget.showExpenses,
              );
            },
          ),
        ),
        if (keys.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(keys.length, (index) {
                final bool isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.colors.textMain
                        : widget.colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class TextDotPainter extends FlDotPainter {
  final double radius;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final String text;
  final TextStyle textStyle;
  final double yOffset;

  final TextPainter? tp;

  TextDotPainter({
    required this.radius,
    required this.color,
    required this.strokeColor,
    required this.strokeWidth,
    required this.text,
    required this.textStyle,
    required this.yOffset,
  }) : tp = text.isNotEmpty
           ? (TextPainter(
               text: TextSpan(text: text, style: textStyle),
               textDirection: ui.TextDirection.ltr,
             )..layout())
           : null;

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    return b;
  }

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetInCanvas, radius, paint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(offsetInCanvas, radius, strokePaint);
    }

    if (tp != null) {
      final dx = offsetInCanvas.dx - (tp!.width / 2);
      final dy = offsetInCanvas.dy + yOffset - (yOffset < 0 ? tp!.height : 0);
      tp!.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  Size getSize(FlSpot spot) => Size(radius * 2, radius * 2);

  @override
  List<Object?> get props => [
    radius,
    color,
    strokeColor,
    strokeWidth,
    text,
    textStyle,
    yOffset,
  ];
}

class _TrendCardWidget extends StatefulWidget {
  final String currency;
  final Map<String, Map<String, int>> data;
  final AppColorsExtension colors;
  final bool showExpenses;

  const _TrendCardWidget({
    required this.currency,
    required this.data,
    required this.colors,
    required this.showExpenses,
  });

  @override
  State<_TrendCardWidget> createState() => _TrendCardWidgetState();
}

class _TrendCardWidgetState extends State<_TrendCardWidget> {
  late ScrollController _scrollController;
  late List<String> months;
  late double maxY;

  int _focusedIndex = 0;

  late List<FlSpot> _incomeSpots;
  late List<FlSpot> _expenseSpots;

  @override
  void initState() {
    super.initState();
    months = widget.data.keys.toList();

    maxY = 0.0;
    for (var m in widget.data.values) {
      final double inc = (m['incomes'] ?? 0) / 100.0;
      final double exp = (m['expenses'] ?? 0) / 100.0;
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }
    if (maxY == 0) maxY = 100;
    maxY = maxY * 1.2;

    _incomeSpots = _generateSpots('incomes');
    _expenseSpots = _generateSpots('expenses');

    final double initialOffset = months.length > 1 ? (months.length - 1) * 60.0 : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _focusedIndex = months.length > 1 ? months.length - 1 : 0;

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final int newIndex = (_scrollController.offset / 60.0).round().clamp(
        0,
        months.isNotEmpty ? months.length - 1 : 0,
      );
      if (_focusedIndex != newIndex) {
        setState(() => _focusedIndex = newIndex);
      }
    });
  }

  List<FlSpot> _generateSpots(String key) {
    int i = 0;
    return widget.data.values.map((v) {
      final double val = (v[key] ?? 0) / 100.0;
      return FlSpot((i++).toDouble(), val);
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openMonthTransactions(int index) {
    if (months.isEmpty) return;
    final monthStr = months[index];
    final parts = monthStr.split('-');
    final tapMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatsMonthBottomSheet(
          statsMonth: tapMonth,
          baseCurrencySymbol: AppCurrency.fromCode(widget.currency).symbol,
          showExpenses: widget.showExpenses,
        );
      },
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color, bool isIncome) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final bool isFocused = index == _focusedIndex;

          final double incVal = _incomeSpots[index].y;
          final double expVal = _expenseSpots[index].y;

          double offset = -18.0;
          if ((incVal - expVal).abs() < (maxY * 0.15)) {
            if (spot.y < (maxY * 0.15)) {
              if (incVal >= expVal) {
                offset = isIncome ? -34.0 : -16.0;
              } else {
                offset = isIncome ? -16.0 : -34.0;
              }
            } else {
              if (incVal >= expVal) {
                offset = isIncome ? -18.0 : 14.0;
              } else {
                offset = isIncome ? 14.0 : -18.0;
              }
            }
          }

          String label = '';
          if (isFocused) {
            label = CurrencyFormatter.format((spot.y * 100).round());
          }

          return TextDotPainter(
            radius: isFocused ? 5.0 : 2.5,
            color: isFocused ? color : color.withValues(alpha: 0.3),
            strokeColor: widget.colors.cardBg,
            strokeWidth: isFocused ? 2.0 : 0.0,
            text: label,
            yOffset: offset,
            textStyle: TextStyle(
              color: color.withValues(alpha: isFocused ? 1.0 : 0.6),
              fontWeight: isFocused ? FontWeight.w900 : FontWeight.w600,
              fontSize: isFocused ? 12 : 9,
              shadows: [
                Shadow(
                  color: widget.colors.cardBg,
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
                Shadow(
                  color: widget.colors.cardBg,
                  blurRadius: 2,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String symbol = AppCurrency.fromCode(widget.currency).symbol;
    final double interval = maxY / 5;

    final String focusedYear = months.isEmpty
        ? DateTime.now().year.toString()
        : months[_focusedIndex].split('-')[0];

    final yearData = widget.data.entries
        .where((e) => e.key.startsWith(focusedYear))
        .toList();
    int totalInc = 0, totalExp = 0;
    for (var m in yearData) {
      totalInc += (m.value['incomes'] ?? 0);
      totalExp += (m.value['expenses'] ?? 0);
    }
    final int monthCount = yearData.isEmpty ? 1 : yearData.length;

    final double avgInc = totalInc / monthCount;
    final double avgExp = totalExp / monthCount;

    final String maxLabel = NumberFormat.compact(
      locale: context.locale.languageCode,
    ).format(maxY);
    double leftAxisWidth = 24.0 + (maxLabel.length * 8.0) + 8.0;
    if (leftAxisWidth < 50) leftAxisWidth = 50.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👇 ОНОВЛЕНО: Стильна плашка з іконкою валюти
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'history_trends'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.colors.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.only(
                        left: 4,
                        right: 12,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.colors.textSecondary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: widget.colors.cardBg,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              symbol, // $ або ₴
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.colors.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.currency, // USD або UAH
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: widget.colors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              builder: (context, opacity, child) {
                return Opacity(opacity: opacity, child: child);
              },
              child: GestureDetector(
                onTap: () => _openMonthTransactions(_focusedIndex),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double chartWidth = months.isEmpty
                        ? 0
                        : (months.length - 1) * 60.0;

                    final incomesBar = _lineData(
                      _incomeSpots,
                      widget.colors.income,
                      true,
                    );
                    final expensesBar = _lineData(
                      _expenseSpots,
                      widget.colors.expense,
                      false,
                    );

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            dragStartBehavior: DragStartBehavior.down,
                            physics: const ClampingScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth / 2,
                              ),
                              child: SizedBox(
                                width: chartWidth,
                                child: LineChart(
                                  LineChartData(
                                    minY: 0,
                                    maxY: maxY,
                                    minX: 0,
                                    maxX: months.length > 1
                                        ? (months.length - 1).toDouble()
                                        : 0.1,
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final int index = value.toInt();
                                            if (index < 0 ||
                                                index >= months.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final DateTime d = DateTime(
                                              int.parse(
                                                months[index].split('-')[0],
                                              ),
                                              int.parse(
                                                months[index].split('-')[1],
                                              ),
                                            );
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10.0,
                                              ),
                                              child: Text(
                                                DateFormat(
                                                  'MMM yy',
                                                  context.locale.languageCode,
                                                ).format(d),
                                                style: TextStyle(
                                                  color: widget
                                                      .colors
                                                      .textSecondary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [incomesBar, expensesBar],
                                    showingTooltipIndicators: [],
                                    lineTouchData: const LineTouchData(
                                      enabled: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: maxY,
                                minX: 0,
                                maxX: 1,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  drawHorizontalLine: true,
                                  horizontalInterval: interval,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: widget.colors.textSecondary
                                        .withValues(alpha: 0.15),
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (v, m) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: leftAxisWidth,
                                      interval: interval,
                                      getTitlesWidget: (value, meta) {
                                        if (value == 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return Container(
                                          padding: const EdgeInsets.only(
                                            left: 24.0,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            NumberFormat.compact(
                                              locale:
                                                  context.locale.languageCode,
                                            ).format(value),
                                            style: TextStyle(
                                              color:
                                                  widget.colors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.normal,
                                              shadows: [
                                                Shadow(
                                                  color: widget.colors.cardBg,
                                                  blurRadius: 4,
                                                ),
                                                Shadow(
                                                  color: widget.colors.cardBg,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: const [FlSpot(0, 0)],
                                    color: Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: constraints.maxWidth / 2 - 0.5,
                          top: 0,
                          bottom: 30,
                          child: IgnorePointer(
                            child: Container(
                              width: 1,
                              color: widget.colors.textMain.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                appPageRoute(
                  YearSummaryScreen(
                    currency: widget.currency,
                    data: widget.data,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: widget.colors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.colors.accent.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      PulsingIcon(
                        icon: Icons.insights_rounded,
                        size: 18,
                        color: widget.colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'average_for_year'.tr(args: [focusedYear]),
                          style: TextStyle(
                            color: widget.colors.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: widget.colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _avgMetric(
                          icon: Icons.arrow_downward_rounded,
                          color: widget.colors.income,
                          label: 'income'.tr(),
                          value:
                              '${CurrencyFormatter.format(avgInc.round())} $symbol',
                        ),
                      ),
                      _avgDivider(),
                      Expanded(
                        child: _avgMetric(
                          icon: Icons.savings_rounded,
                          color: widget.colors.accent,
                          label: 'savings'.tr(),
                          value:
                              '${(avgInc > 0 ? ((avgInc - avgExp) / avgInc * 100) : 0).round()}%',
                        ),
                      ),
                      _avgDivider(),
                      Expanded(
                        child: _avgMetric(
                          icon: Icons.arrow_upward_rounded,
                          color: widget.colors.expense,
                          label: 'stats_expenses'.tr(),
                          value:
                              '${CurrencyFormatter.format(avgExp.round())} $symbol',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgDivider() => Container(
    width: 1,
    height: 34,
    color: widget.colors.textSecondary.withValues(alpha: 0.15),
  );

  Widget _avgMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: widget.colors.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
