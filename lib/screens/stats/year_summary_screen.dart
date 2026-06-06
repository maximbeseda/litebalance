import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/currency_formatter.dart';
import '../../models/app_currency.dart';

class YearSummaryScreen extends StatelessWidget {
  final String currency;
  final Map<String, Map<String, int>> data;

  const YearSummaryScreen({
    super.key,
    required this.currency,
    required this.data,
  });

  // Допоміжна функція для отримання локалізованої назви місяця
  String _getMonthName(BuildContext context, String yyyyMm) {
    if (yyyyMm.isEmpty) return '';
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return '';
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    return DateFormat(
      'MMMM',
      context.locale.languageCode,
    ).format(d).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final symbol = AppCurrency.fromCode(currency).symbol;

    int grandTotalInc = 0;
    int grandTotalExp = 0;
    final Map<String, Map<String, Map<String, int>>> groupedByYear = {};

    data.forEach((monthStr, values) {
      final String year = monthStr.split('-')[0];
      if (!groupedByYear.containsKey(year)) {
        groupedByYear[year] = {};
      }
      groupedByYear[year]![monthStr] = values;

      grandTotalInc += values['incomes'] ?? 0;
      grandTotalExp += values['expenses'] ?? 0;
    });

    final int grandNet = grandTotalInc - grandTotalExp;
    final double grandSavingsRate = grandTotalInc > 0
        ? (grandNet / grandTotalInc) * 100
        : 0.0;

    final List<String> sortedYears = groupedByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: Container(
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
          child: Column(
            children: [
              _buildHeader(context, colors),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  children: [
                    _buildGrandTotalCard(
                      colors,
                      grandNet,
                      grandSavingsRate,
                      symbol,
                      grandTotalInc,
                      grandTotalExp,
                    ),
                    const SizedBox(height: 32),

                    ...sortedYears.map((year) {
                      return _buildYearCard(
                        context,
                        year,
                        groupedByYear[year]!,
                        symbol,
                        colors,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 8.0,
        top: 4.0,
        right: 8.0,
        bottom: 8.0,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'all_time_summary'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGrandTotalCard(
    AppColorsExtension colors,
    int net,
    double rate,
    String symbol,
    int totalInc,
    int totalExp,
  ) {
    final Color baseColor = net >= 0 ? colors.income : colors.expense;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor.withValues(alpha: 0.8), baseColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'net_profit_year'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Повна сума без копійок; FittedBox гарантує, що навіть великі
          // числа вмістяться на вузьких екранах.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${net > 0 ? '+' : ''}${CurrencyFormatter.formatFull(net)} $symbol",
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Розбивка доходи / витрати під чистим результатом.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _grandBreakdown(Icons.arrow_downward_rounded, totalInc, symbol),
              const SizedBox(width: 20),
              _grandBreakdown(Icons.arrow_upward_rounded, totalExp, symbol),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${'savings_rate'.tr()}: ${rate.toStringAsFixed(1)}%",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grandBreakdown(IconData icon, int value, String symbol) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${CurrencyFormatter.formatFull(value)} $symbol',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearCard(
    BuildContext context,
    String year,
    Map<String, Map<String, int>> yearData,
    String symbol,
    AppColorsExtension colors,
  ) {
    int totalInc = 0;
    int totalExp = 0;

    int maxMonthInc = 0;
    int maxMonthExp = 0;
    int minMonthInc = 999999999;
    int minMonthExp = 999999999;

    String maxIncName = '';
    String maxExpName = '';
    String minIncName = '';
    String minExpName = '';

    yearData.forEach((month, values) {
      final int inc = values['incomes'] ?? 0;
      final int exp = values['expenses'] ?? 0;

      totalInc += inc;
      totalExp += exp;

      if (inc > maxMonthInc) {
        maxMonthInc = inc;
        maxIncName = _getMonthName(context, month);
      }
      if (exp > maxMonthExp) {
        maxMonthExp = exp;
        maxExpName = _getMonthName(context, month);
      }
      if (inc < minMonthInc && inc > 0) {
        minMonthInc = inc;
        minIncName = _getMonthName(context, month);
      }
      if (exp < minMonthExp && exp > 0) {
        minMonthExp = exp;
        minExpName = _getMonthName(context, month);
      }
    });

    if (minMonthInc == 999999999) minMonthInc = 0;
    if (minMonthExp == 999999999) minMonthExp = 0;

    final int monthsCount = yearData.isNotEmpty ? yearData.length : 1;
    final int avgInc = (totalInc / monthsCount).round();
    final int avgExp = (totalExp / monthsCount).round();
    final int netProfit = totalInc - totalExp;
    final double savingsRate = totalInc > 0 ? (netProfit / totalInc) * 100 : 0;

    final Color netColor = netProfit >= 0 ? colors.income : colors.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                year,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.textMain,
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "${netProfit > 0 ? '+' : ''}${CurrencyFormatter.formatFull(netProfit)} $symbol",
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: netColor,
                        ),
                      ),
                    ),
                    Text(
                      "${'savings'.tr()}: ${savingsRate.round()}%",
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: colors.textSecondary.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),

          // 👇 ОНОВЛЕНО: Використовуємо IntrinsicHeight для ідеальної розділювальної лінії
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: colors.income,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'income'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.income,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _miniStat('total'.tr(), totalInc, symbol, colors),
                      _miniStat('average'.tr(), avgInc, symbol, colors),
                      _miniStat(
                        "${'maximum_month'.tr()}${maxIncName.isNotEmpty ? '\n($maxIncName)' : ''}",
                        maxMonthInc,
                        symbol,
                        colors,
                      ),
                      _miniStat(
                        "${'minimum_month'.tr()}${minIncName.isNotEmpty ? '\n($minIncName)' : ''}",
                        minMonthInc,
                        symbol,
                        colors,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: colors.textSecondary.withValues(alpha: 0.1),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: colors.expense,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'stats_expenses'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.expense,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _miniStat('total'.tr(), totalExp, symbol, colors),
                      _miniStat('average'.tr(), avgExp, symbol, colors),
                      _miniStat(
                        "${'maximum_month'.tr()}${maxExpName.isNotEmpty ? '\n($maxExpName)' : ''}",
                        maxMonthExp,
                        symbol,
                        colors,
                      ),
                      _miniStat(
                        "${'minimum_month'.tr()}${minExpName.isNotEmpty ? '\n($minExpName)' : ''}",
                        minMonthExp,
                        symbol,
                        colors,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    String label,
    int value,
    String symbol,
    AppColorsExtension colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${CurrencyFormatter.formatFull(value)} $symbol',
              maxLines: 1,
              style: TextStyle(
                color: colors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
