import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_currency.dart';
import '../../utils/currency_formatter.dart';
import '../../theme/app_colors_extension.dart';
import '../../providers/all_providers.dart';
import '../../utils/icon_helper.dart';
import '../common/history_search_bar.dart';
import '../common/app_empty_state.dart';
import '../common/category_halo_icon.dart';

class HistoryBottomSheet extends ConsumerStatefulWidget {
  final Category category;
  final List<Transaction> transactions;
  final List<Category> allCategories;
  final Function(Transaction) onDelete;
  final Function(Transaction) onEdit;

  const HistoryBottomSheet({
    super.key,
    required this.category,
    required this.transactions,
    required this.allCategories,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  ConsumerState<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends ConsumerState<HistoryBottomSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;
  final Set<String> _localDeletedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(filterProvider.notifier).initForCategory(widget.category.id);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      final filterState = ref.read(filterProvider);

      if (filterState.hasMore && !_isFetchingMore) {
        _isFetchingMore = true;
        await ref.read(filterProvider.notifier).loadNextPage();
        if (mounted) _isFetchingMore = false;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final catState = ref.watch(categoryProvider);
    final filterState = ref.watch(filterProvider);

    // Пріоритет: результати провайдера, якщо вони є. Якщо немає (початок завантаження) — дані з конструктора.
    final categoryHistory =
        (filterState.results.isEmpty && filterState.searchQuery.isEmpty)
        ? widget.transactions
        : filterState.results;

    final allCategories = catState.allCategoriesList;

    // 👇 ВИПРАВЛЕНО: показуємо лоадер пагінації тільки якщо вже є завантажені результати
    final showLoader =
        filterState.hasMore &&
        filterState.searchQuery.isEmpty &&
        filterState.results.isNotEmpty;
    final categoryMap = {for (var c in allCategories) c.id: c};

    // Кешуємо переклади для швидкості
    final trOutgoing = 'outgoing_transfer'.tr();
    final trTopUp = 'top_up'.tr();

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
      height: MediaQuery.of(context).size.height * 0.75,
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
                icon: IconHelper.getIcon(widget.category.icon),
                bgColor: Color(widget.category.bgColor),
                iconColor: Color(widget.category.iconColor),
                size: 60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'history_category'.tr(args: [widget.category.name]),
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

          HistorySearchBar(specificType: widget.category.type),

          const SizedBox(height: 12),

          Expanded(
            child:
                (filterState.isLoading &&
                    categoryHistory
                        .isEmpty) // Показуємо лоадер ТІЛЬКИ якщо даних немає взагалі
                ? const Center(child: CircularProgressIndicator())
                : categoryHistory.isEmpty
                ? _buildEmptyState(colors, filterState.searchQuery.isNotEmpty)
                : ListView.builder(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categoryHistory.length + (showLoader ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == categoryHistory.length) {
                        return _buildBottomLoader(colors);
                      }

                      final t = categoryHistory[index];
                      if (_localDeletedIds.contains(t.id)) {
                        return const SizedBox.shrink();
                      }

                      return _buildTransactionItem(
                        context,
                        t,
                        colors,
                        categoryMap,
                        trOutgoing,
                        trTopUp,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, bool isSearch) {
    return AppEmptyState(
      icon: isSearch
          ? Icons.search_off_rounded
          : Icons.receipt_long_outlined,
      color: isSearch ? colors.textSecondary : colors.accent,
      title: isSearch ? 'nothing_found'.tr() : 'no_transactions_yet'.tr(),
      subtitle: isSearch
          ? 'nothing_found_hint'.tr()
          : 'no_transactions_hint'.tr(),
    );
  }

  Widget _buildBottomLoader(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction t,
    AppColorsExtension colors,
    Map<String, Category> categoryMap,
    String trOutgoing,
    String trTopUp,
  ) {
    final bool isOut = t.fromId == widget.category.id;
    final String otherId = isOut ? t.toId : t.fromId;
    final otherCat = categoryMap[otherId];

    // Очищення нотатки
    String customNote = t.title.trim();
    final bool isDefaultTitle =
        customNote.isEmpty ||
        customNote.contains('➡️') ||
        customNote == otherCat?.name ||
        customNote == widget.category.name ||
        customNote == trOutgoing ||
        customNote == trTopUp;
    if (isDefaultTitle) customNote = '';

    // Розрахунок сум
    final int mainAmount = isOut ? t.amount : (t.targetAmount ?? t.amount);
    final String mainCurrency = isOut
        ? t.currency
        : (t.targetCurrency ?? t.currency);
    final int secondaryAmount = isOut ? (t.targetAmount ?? t.amount) : t.amount;
    final String secondaryCurrency = isOut
        ? (t.targetCurrency ?? t.currency)
        : t.currency;

    final bool isMultiCurrency =
        mainCurrency != secondaryCurrency && t.targetCurrency != null;

    final String mainSymbol = AppCurrency.fromCode(mainCurrency).symbol;
    final String secondarySymbol = AppCurrency.fromCode(
      secondaryCurrency,
    ).symbol;

    // Колір та префікс
    String prefix = '';
    Color amountColor = colors.textMain;

    if (widget.category.type == CategoryType.income) {
      prefix = '+';
      amountColor = colors.income;
    } else if (widget.category.type == CategoryType.expense) {
      prefix = '-';
      amountColor = colors.expense;
    } else {
      prefix = isOut ? '-' : '+';
      if (otherCat?.type == CategoryType.account) {
        amountColor = colors.textSecondary;
      } else {
        amountColor = isOut ? colors.expense : colors.income;
      }
    }

    return Dismissible(
      key: Key('history_item_${t.id}'),
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
        setState(() => _localDeletedIds.add(t.id));
        widget.onDelete(t);
      },
      child: Material(
        // 👈 ДОДАЄМО ПРОЗОРЕ ПОЛОТНО
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: () async => await widget.onEdit(t),
          leading: otherCat != null
              ? CircleAvatar(
                  backgroundColor: Color(otherCat.bgColor),
                  child: Icon(
                    IconHelper.getIcon(otherCat.icon),
                    color: Color(otherCat.iconColor),
                    size: 20,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOut ? Icons.arrow_outward : Icons.arrow_downward,
                    color: isOut ? colors.expense : colors.income,
                    size: 20,
                  ),
                ),
          title: Text(
            otherCat?.name ?? (isOut ? trOutgoing : trTopUp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textMain,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fastDateFormat(t.date),
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              if (customNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 14,
                        color: colors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customNote,
                          maxLines: 1,
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
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${CurrencyFormatter.format(mainAmount)} $mainSymbol',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                      fontSize: 14,
                    ),
                  ),
                  if (isMultiCurrency)
                    Text(
                      '~ ${CurrencyFormatter.format(secondaryAmount)} $secondarySymbol',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
