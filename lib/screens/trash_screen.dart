import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/all_providers.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_empty_state.dart';
import '../models/app_currency.dart';
import '../utils/currency_formatter.dart';
import '../utils/icon_helper.dart';

enum TrashItemType { category, transaction, subscription }

class TrashItem {
  final String id;
  final TrashItemType type;
  final DateTime deletedAt;
  final int daysLeft;
  final Widget titleWidget;
  final Widget subtitleWidget;
  final String? amountStr;
  final Color amountColor;
  final Widget icon;
  final dynamic rawData;

  TrashItem({
    required this.id,
    required this.type,
    required this.deletedAt,
    required this.daysLeft,
    required this.titleWidget,
    required this.subtitleWidget,
    this.amountStr,
    this.amountColor = Colors.grey,
    required this.icon,
    required this.rawData,
  });
}

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  bool _isCleaningUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutoCleanup();
    });
  }

  Future<void> _runAutoCleanup() async {
    final catState = ref.read(categoryProvider);
    final txAsync = ref.read(transactionProvider);
    final txState = txAsync.value;

    // 👇 ВИПРАВЛЕНО: дістаємо значення з AsyncValue
    final subAsync = ref.read(subscriptionProvider);
    final subState = subAsync.value;

    final now = DateTime.now();
    bool needsRefresh = false;

    for (var cat in catState.deletedCategories) {
      if (cat.deletedAt != null &&
          now.difference(cat.deletedAt!).inDays >= 30) {
        await ref.read(categoryProvider.notifier).emptyTrashOrArchive(cat);
        needsRefresh = true;
      }
    }

    if (txState != null) {
      for (var tx in txState.deletedHistory) {
        if (tx.deletedAt != null &&
            now.difference(tx.deletedAt!).inDays >= 30) {
          await ref.read(transactionProvider.notifier).deletePermanently(tx);
          needsRefresh = true;
        }
      }
    }

    if (subState != null) {
      for (var sub in subState.deletedSubscriptions) {
        if (sub.deletedAt != null &&
            now.difference(sub.deletedAt!).inDays >= 30) {
          await ref
              .read(subscriptionProvider.notifier)
              .deletePermanently(sub.id);
          needsRefresh = true;
        }
      }
    }

    if (needsRefresh && mounted) {
      setState(() {});
    }
  }

  Future<void> _emptyTrash() async {
    final bool confirm = await AppDialog.destructive(
      context,
      title: 'empty_trash_title'.tr(),
      message: 'empty_trash_msg'.tr(),
      confirmText: 'delete'.tr(),
    );

    if (!confirm) return;

    setState(() => _isCleaningUp = true);

    final catState = ref.read(categoryProvider);
    final txAsync = ref.read(transactionProvider);
    final txState = txAsync.value;

    // 👇 ВИПРАВЛЕНО
    final subAsync = ref.read(subscriptionProvider);
    final subState = subAsync.value;

    for (var cat in catState.deletedCategories) {
      await ref.read(categoryProvider.notifier).emptyTrashOrArchive(cat);
    }

    if (txState != null) {
      for (var tx in txState.deletedHistory) {
        await ref.read(transactionProvider.notifier).deletePermanently(tx);
      }
    }

    if (subState != null) {
      for (var sub in subState.deletedSubscriptions) {
        await ref.read(subscriptionProvider.notifier).deletePermanently(sub.id);
      }
    }

    if (mounted) {
      setState(() => _isCleaningUp = false);
      AppSnackbar.success(context, 'trash_emptied'.tr());
    }
  }

  List<TrashItem> _buildTrashItems(AppColorsExtension colors) {
    final catState = ref.watch(categoryProvider);
    final txAsync = ref.watch(transactionProvider);
    final txState = txAsync.value;

    // 👇 ВИПРАВЛЕНО
    final subAsync = ref.watch(subscriptionProvider);
    final subState = subAsync.value;

    final allCats = catState.allCategoriesList;
    final catMap = {for (var c in allCats) c.id: c};

    final List<TrashItem> items = [];
    final now = DateTime.now();

    // 1. Категорії
    for (var cat in catState.deletedCategories) {
      if (cat.deletedAt == null) continue;
      int daysLeft = 30 - now.difference(cat.deletedAt!).inDays;
      if (daysLeft < 0) daysLeft = 0;

      items.add(
        TrashItem(
          id: cat.id,
          type: TrashItemType.category,
          deletedAt: cat.deletedAt!,
          daysLeft: daysLeft,
          titleWidget: Text(
            cat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitleWidget: Text(
            'category'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(cat.bgColor),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconHelper.getIcon(cat.icon),
              color: Color(cat.iconColor),
              size: 20,
            ),
          ),
          rawData: cat,
        ),
      );
    }

    // 2. Транзакції
    if (txState != null) {
      for (var tx in txState.deletedHistory) {
        if (tx.deletedAt == null) continue;
        int daysLeft = 30 - now.difference(tx.deletedAt!).inDays;
        if (daysLeft < 0) daysLeft = 0;

        final fromCat = catMap[tx.fromId];
        final toCat = catMap[tx.toId];
        final deletedCatName = 'deleted_category'.tr();

        Color amountColor = colors.textSecondary;
        IconData txIconData = Icons.swap_horiz;
        Color txIconColor = colors.textSecondary;

        final String fromName = fromCat?.name ?? deletedCatName;
        final String toName = toCat?.name ?? deletedCatName;

        if (fromCat != null && toCat != null) {
          if (fromCat.type == CategoryType.income &&
              toCat.type == CategoryType.account) {
            amountColor = colors.income;
            txIconData = Icons.call_made;
            txIconColor = colors.income;
          } else if (fromCat.type == CategoryType.account &&
              toCat.type == CategoryType.expense) {
            amountColor = colors.expense;
            txIconData = Icons.call_received;
            txIconColor = colors.expense;
          }
        }

        final String sym = AppCurrency.fromCode(tx.currency).symbol;

        final titleWidget = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: fromName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textMain,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextSpan(
                text: toName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        final subtitleWidget = Text(
          'transaction'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        );

        items.add(
          TrashItem(
            id: tx.id,
            type: TrashItemType.transaction,
            deletedAt: tx.deletedAt!,
            daysLeft: daysLeft,
            titleWidget: titleWidget,
            subtitleWidget: subtitleWidget,
            amountStr: '${CurrencyFormatter.format(tx.amount)} $sym',
            amountColor: amountColor,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: txIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(txIconData, color: txIconColor, size: 20),
            ),
            rawData: tx,
          ),
        );
      }
    }

    // 3. Підписки
    if (subState != null) {
      for (var sub in subState.deletedSubscriptions) {
        if (sub.deletedAt == null) continue;
        int daysLeft = 30 - now.difference(sub.deletedAt!).inDays;
        if (daysLeft < 0) daysLeft = 0;

        final String sym = AppCurrency.fromCode(sub.currency).symbol;

        items.add(
          TrashItem(
            id: sub.id,
            type: TrashItemType.subscription,
            deletedAt: sub.deletedAt!,
            daysLeft: daysLeft,
            titleWidget: Text(
              sub.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitleWidget: Text(
              'subscription'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            amountStr: '${CurrencyFormatter.format(sub.amount)} $sym',
            amountColor: colors.textMain,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_repeat,
                color: Colors.blueAccent,
                size: 20,
              ),
            ),
            rawData: sub,
          ),
        );
      }
    }

    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final items = _buildTrashItems(colors);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.bgGradientStart, colors.bgGradientEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'trash'.tr(),
            style: TextStyle(
              color: colors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: colors.textMain),
          actions: [
            if (items.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete_sweep, color: colors.expense),
                onPressed: _isCleaningUp ? null : _emptyTrash,
                tooltip: 'empty_trash'.tr(),
              ),
          ],
        ),
        body: _isCleaningUp
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? AppEmptyState(
                icon: Icons.delete_outline,
                title: 'trash_empty'.tr(),
                subtitle: 'trash_empty_hint'.tr(),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final daysColor = item.daysLeft <= 3
                      ? Colors.redAccent
                      : colors.textSecondary;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        item.icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              item.titleWidget,
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(child: item.subtitleWidget),
                                  if (item.amountStr != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      item.amountStr!,
                                      style: TextStyle(
                                        color: item.amountColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: daysColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'days_left'.tr(
                                        args: [item.daysLeft.toString()],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: daysColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.blueAccent,
                                  size: 22,
                                ),
                                tooltip: 'restore'.tr(),
                                onPressed: () async {
                                  if (item.type == TrashItemType.category) {
                                    await ref
                                        .read(categoryProvider.notifier)
                                        .restoreFromTrash(item.rawData);
                                  } else if (item.type ==
                                      TrashItemType.transaction) {
                                    await ref
                                        .read(transactionProvider.notifier)
                                        .restoreFromTrash(item.rawData);
                                  } else if (item.type ==
                                      TrashItemType.subscription) {
                                    await ref
                                        .read(subscriptionProvider.notifier)
                                        .restoreFromTrash(item.rawData);
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.delete_forever,
                                  color: colors.expense,
                                  size: 22,
                                ),
                                tooltip: 'delete_forever'.tr(),
                                onPressed: () async {
                                  if (item.type == TrashItemType.category) {
                                    await ref
                                        .read(categoryProvider.notifier)
                                        .emptyTrashOrArchive(item.rawData);
                                  } else if (item.type ==
                                      TrashItemType.transaction) {
                                    await ref
                                        .read(transactionProvider.notifier)
                                        .deletePermanently(item.rawData);
                                  } else if (item.type ==
                                      TrashItemType.subscription) {
                                    await ref
                                        .read(subscriptionProvider.notifier)
                                        .deletePermanently(item.id);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
