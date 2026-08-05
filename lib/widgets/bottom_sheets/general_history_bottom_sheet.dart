import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_currency.dart';
import '../../utils/amount_text.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../theme/app_colors_extension.dart';
import '../../providers/all_providers.dart';
import '../../utils/icon_helper.dart';
import '../common/history_search_bar.dart';
import '../common/app_empty_state.dart';
import '../common/category_halo_icon.dart';

class GeneralHistoryBottomSheet extends ConsumerStatefulWidget {
  final String title;
  final CategoryType filterType;
  final List<Transaction> transactions;
  final List<Category> allCategories;
  final Function(Transaction) onDelete;
  final Function(Transaction) onEdit;

  const GeneralHistoryBottomSheet({
    super.key,
    required this.title,
    required this.filterType,
    required this.transactions,
    required this.allCategories,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  ConsumerState<GeneralHistoryBottomSheet> createState() =>
      _GeneralHistoryBottomSheetState();
}

class _GeneralHistoryBottomSheetState
    extends ConsumerState<GeneralHistoryBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;

  // 👇 ДОДАНО: Локальний кеш видалених транзакцій
  final Set<String> _localDeletedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(filterProvider.notifier);
      notifier.initGeneral();
      notifier.setCategoryType(widget.filterType);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      final filterState = ref.read(filterProvider);

      // Видалили блокування по searchQuery. Пагінація працюватиме завжди!
      if (filterState.hasMore && !_isFetchingMore) {
        _isFetchingMore = true;
        await ref.read(filterProvider.notifier).loadNextPage();
        _isFetchingMore = false;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _fastDateFormat(BuildContext context, DateTime d) {
    final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return DateFormatter.formatWithTime(d, locale);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final catState = ref.watch(categoryProvider);
    final filterState = ref.watch(filterProvider);

    final allCategories = catState.allCategoriesList;
    final categoryMap = {for (var c in allCategories) c.id: c};

    // Фолбек до ініціалізації фільтра — дані з конструктора, але відфільтровані
    // по типу цього перегляду (як і SQL-запит), інакше для типу без транзакцій
    // показалася б уся історія. Беремо список категорій із конструктора — саме
    // він авторитетний для переданих транзакцій.
    final typeCategoryIds = {
      for (final c in widget.allCategories)
        if (c.type == widget.filterType) c.id,
    };
    final filteredHistory =
        (filterState.results.isEmpty && filterState.searchQuery.isEmpty)
        ? widget.transactions
              .where(
                (t) =>
                    typeCategoryIds.contains(t.fromId) ||
                    typeCategoryIds.contains(t.toId),
              )
              .toList()
        : filterState.results;

    final showLoader = filterState.hasMore && filterState.searchQuery.isEmpty;

    final trUnknown = 'unknown'.tr();
    final trOutgoing = 'outgoing_transfer'.tr();
    final trTopUp = 'top_up'.tr();

    final Map<String, String> currencyCache = {};

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CategoryHaloIcon(
                icon: Icons.receipt_long_rounded,
                bgColor: colors.accent,
                iconColor: Colors.white,
                size: 60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          HistorySearchBar(specificType: widget.filterType),

          const SizedBox(height: 12),

          Expanded(
            child: (filterState.isLoading && filteredHistory.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : filteredHistory.isEmpty
                ? Builder(
                    builder: (context) {
                      final isSearch = filterState.searchQuery.isNotEmpty;
                      return AppEmptyState(
                        icon: isSearch
                            ? Icons.search_off_rounded
                            : Icons.receipt_long_outlined,
                        color: isSearch
                            ? colors.textSecondary
                            : colors.accent,
                        title: isSearch
                            ? 'nothing_found'.tr()
                            : 'no_transactions_yet'.tr(),
                        subtitle: isSearch
                            ? 'nothing_found_hint'.tr()
                            : 'no_transactions_hint'.tr(),
                      );
                    },
                  )
                : ListView.builder(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredHistory.length + (showLoader ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredHistory.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
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

                      final t = filteredHistory[index];

                      // 👇 ДОДАНО: Перевірка на локально видалену транзакцію
                      if (_localDeletedIds.contains(t.id)) {
                        return const SizedBox.shrink();
                      }

                      final fromCat = categoryMap[t.fromId];
                      final toCat = categoryMap[t.toId];

                      final String fromName = fromCat?.name ?? trUnknown;
                      final String toName = toCat?.name ?? trUnknown;

                      final bool isIncome =
                          fromCat?.type == CategoryType.income;
                      final bool isTransfer =
                          fromCat?.type == CategoryType.account &&
                          toCat?.type == CategoryType.account;

                      String customNote = t.title.trim();

                      final bool isDefaultTitle =
                          customNote.isEmpty ||
                          customNote.contains('➡️') ||
                          customNote == fromName ||
                          customNote == toName ||
                          customNote == trOutgoing ||
                          customNote == trTopUp;

                      if (isDefaultTitle) customNote = '';

                      // ЛОГІКА ДЛЯ ЗАГАЛЬНОЇ ІСТОРІЇ
                      // Головною завжди є оригінальна сума списання (amount / currency)
                      final int mainAmount = t.amount;
                      final String mainCurrency = t.currency;

                      // Додатковою є цільова сума (targetAmount / targetCurrency)
                      final int secondaryAmount = t.targetAmount ?? t.amount;
                      final String secondaryCurrency =
                          t.targetCurrency ?? t.currency;

                      final bool isMultiCurrency =
                          mainCurrency != secondaryCurrency &&
                          t.targetCurrency != null;

                      final String mainSymbol = currencyCache.putIfAbsent(
                        mainCurrency,
                        () => AppCurrency.fromCode(mainCurrency).symbol,
                      );
                      final String secondarySymbol = currencyCache.putIfAbsent(
                        secondaryCurrency,
                        () => AppCurrency.fromCode(secondaryCurrency).symbol,
                      );

                      String prefix = '-';
                      Color amountColor = colors.expense;

                      if (widget.filterType == CategoryType.income) {
                        prefix = '+';
                        amountColor = colors.income;
                      } else if (widget.filterType == CategoryType.expense) {
                        prefix = '-';
                        amountColor = colors.expense;
                      } else if (widget.filterType == CategoryType.account) {
                        if (isIncome) {
                          prefix = '+';
                          amountColor = colors.income;
                        } else if (isTransfer) {
                          prefix = '';
                          amountColor = colors.textSecondary;
                        } else {
                          prefix = '-';
                          amountColor = colors.expense;
                        }
                      }

                      return Dismissible(
                        key: Key('gen_history_${t.id}'),
                        direction: DismissDirection.endToStart,
                        resizeDuration: const Duration(milliseconds: 250),
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.expense,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            _localDeletedIds.add(t.id);
                          });
                          widget.onDelete(t);
                        },
                        child: Material(
                          // 👈 ДОДАЄМО ПРОЗОРЕ ПОЛОТНО
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            onTap: () async => await widget.onEdit(t),
                            leading: CircleAvatar(
                              backgroundColor: toCat != null
                                  ? Color(toCat.bgColor)
                                  : colors.iconBg,
                              child: Icon(
                                toCat != null
                                    ? IconHelper.getIcon(toCat.icon)
                                    : Icons.help_outline,
                                color: toCat != null
                                    ? Color(toCat.iconColor)
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
                                    _fastDateFormat(context, t.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Головна сума
                                    AmountText(
                                      amount:
                                          '$prefix${CurrencyFormatter.format(mainAmount, currencyCode: mainCurrency)}',
                                      symbol: mainSymbol,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: amountColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    // Додаткова сума дрібним шрифтом (тільки для мультивалютних)
                                    if (isMultiCurrency)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2.0,
                                        ),
                                        child: AmountText(
                                          amount:
                                              '~ ${CurrencyFormatter.format(secondaryAmount, currencyCode: secondaryCurrency)}',
                                          symbol: secondarySymbol,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
