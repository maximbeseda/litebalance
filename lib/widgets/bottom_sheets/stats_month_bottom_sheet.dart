import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/app_currency.dart';
import '../../providers/all_providers.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class StatsMonthBottomSheet extends ConsumerStatefulWidget {
  final DateTime statsMonth;
  final String baseCurrencySymbol;
  final bool showExpenses;
  final List<Transaction>? initialTransactions;

  const StatsMonthBottomSheet({
    super.key,
    required this.statsMonth,
    required this.baseCurrencySymbol,
    required this.showExpenses,
    this.initialTransactions,
  });

  @override
  ConsumerState<StatsMonthBottomSheet> createState() =>
      _StatsMonthBottomSheetState();
}

class _StatsMonthBottomSheetState extends ConsumerState<StatsMonthBottomSheet> {
  bool _isFetchingMore = false;
  late bool _showExpenses;

  @override
  void initState() {
    super.initState();
    _showExpenses = widget.showExpenses;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    final filterNotifier = ref.read(filterProvider.notifier);
    filterNotifier.initGeneral();

    filterNotifier.setCategoryType(
      _showExpenses ? CategoryType.expense : CategoryType.income,
    );

    final start = DateTime(widget.statsMonth.year, widget.statsMonth.month, 1);
    final end = DateTime(
      widget.statsMonth.year,
      widget.statsMonth.month + 1,
      0,
      23,
      59,
      59,
    );
    filterNotifier.setDateRange(start, end);
  }

  void _toggleType(bool isExpense) {
    if (_showExpenses == isExpense) return;
    setState(() {
      _showExpenses = isExpense;
    });
    _fetchData();
  }

  String _fastDateFormat(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.${d.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final filterState = ref.watch(filterProvider);
    final filteredTxs =
        (filterState.results.isEmpty &&
            filterState.searchQuery.isEmpty &&
            widget.initialTransactions != null)
        ? widget.initialTransactions!
        : filterState.results;
    final showLoader = filterState.hasMore;

    final allCategories = ref.watch(categoryProvider).allCategoriesList;
    final categoryMap = {for (var c in allCategories) c.id: c};

    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    final trUnknown = 'unknown'.tr();
    final trOutgoing = 'outgoing_transfer'.tr();
    final trTopUp = 'top_up'.tr();

    final Map<String, String> currencyCache = {};

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.iconBg,
                      child: Icon(
                        Icons.calendar_month,
                        color: colors.textMain,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormatter.formatMonthYear(
                              widget.statsMonth,
                              localeCode,
                            ),
                            style: TextStyle(
                              color: colors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'history'.tr(),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ПЕРЕМИКАЧ (Доходи зліва, Витрати справа)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        // Якщо НЕ витрати (доходи) - вліво, якщо витрати - вправо
                        alignment: !_showExpenses
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // ЛІВА КНОПКА: ДОХОДИ
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _toggleType(false),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  'income'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_showExpenses
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: !_showExpenses
                                        ? colors.income
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // ПРАВА КНОПКА: ВИТРАТИ
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _toggleType(true),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  'stats_expenses'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _showExpenses
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: _showExpenses
                                        ? colors.expense
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: colors.textSecondary.withValues(alpha: 0.1),
              ),

              Expanded(
                child:
                    (filterState.isLoading &&
                        filteredTxs.isEmpty &&
                        widget.initialTransactions == null)
                    ? const Center(child: CircularProgressIndicator())
                    : filteredTxs.isEmpty
                    ? Center(
                        child: Text(
                          'no_data'.tr(),
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 150) {
                            if (filterState.hasMore && !_isFetchingMore) {
                              _isFetchingMore = true;
                              ref
                                  .read(filterProvider.notifier)
                                  .loadNextPage()
                                  .then((_) {
                                    if (mounted) _isFetchingMore = false;
                                  });
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: controller,
                          physics: const BouncingScrollPhysics(),
                          cacheExtent: 1000,
                          itemCount: filteredTxs.length + (showLoader ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredTxs.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final tx = filteredTxs[index];

                            final fromCat = categoryMap[tx.fromId];
                            final toCat = categoryMap[tx.toId];

                            final String fromName = fromCat?.name ?? trUnknown;
                            final String toName = toCat?.name ?? trUnknown;

                            String customNote = tx.title.trim();

                            final bool isDefaultTitle =
                                customNote.isEmpty ||
                                customNote.contains('➡️') ||
                                customNote == fromName ||
                                customNote == toName ||
                                customNote == trOutgoing ||
                                customNote == trTopUp;

                            if (isDefaultTitle) customNote = '';

                            final bool isIncome =
                                fromCat?.type == CategoryType.income;
                            final bool isTransfer =
                                fromCat?.type == CategoryType.account &&
                                toCat?.type == CategoryType.account;

                            final iconCat = isIncome ? toCat : fromCat;

                            // 👇 ЛОГІКА ПЕРСПЕКТИВИ ДЛЯ МУЛЬТИВАЛЮТНОСТІ
                            final int mainAmount = tx.amount;
                            final String mainCurrency = tx.currency;

                            final int secondaryAmount =
                                tx.targetAmount ?? tx.amount;
                            final String secondaryCurrency =
                                tx.targetCurrency ?? tx.currency;

                            final bool isMultiCurrency =
                                mainCurrency != secondaryCurrency &&
                                tx.targetCurrency != null;

                            final String mainSymbol = currencyCache.putIfAbsent(
                              mainCurrency,
                              () => AppCurrency.fromCode(mainCurrency).symbol,
                            );
                            final String secondarySymbol = currencyCache
                                .putIfAbsent(
                                  secondaryCurrency,
                                  () => AppCurrency.fromCode(
                                    secondaryCurrency,
                                  ).symbol,
                                );

                            final String prefix = isIncome
                                ? '+'
                                : (isTransfer ? '' : '-');
                            final Color amountColor = isIncome
                                ? colors.income
                                : (isTransfer
                                      ? colors.textSecondary
                                      : colors.expense);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: iconCat != null
                                    ? Color(iconCat.bgColor)
                                    : colors.iconBg,
                                child: Icon(
                                  iconCat != null
                                      ? IconData(
                                          iconCat.icon,
                                          fontFamily: 'MaterialIcons',
                                        )
                                      : Icons.help_outline,
                                  color: iconCat != null
                                      ? Color(iconCat.iconColor)
                                      : colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      fromName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textMain,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 14,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      toName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textMain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fastDateFormat(tx.date),
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (customNote.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.notes,
                                            size: 14,
                                            color: colors.textSecondary
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              customNote,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$prefix${CurrencyFormatter.format(mainAmount.abs())} $mainSymbol',
                                    style: TextStyle(
                                      color: amountColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isMultiCurrency)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        '~ ${CurrencyFormatter.format(secondaryAmount.abs())} $secondarySymbol',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
