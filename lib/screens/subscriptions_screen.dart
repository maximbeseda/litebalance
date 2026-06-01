import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/all_providers.dart';
import '../models/app_currency.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/icon_helper.dart';
import '../screens/subscription_screen.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_empty_state.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  void _showSubscriptionDialog(
    BuildContext context, {
    Subscription? subscription,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SubscriptionScreen(subscription: subscription),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 ВИПРАВЛЕНО: Отримуємо AsyncValue та розпаковуємо його
    final subAsync = ref.watch(subscriptionProvider);
    final subState = subAsync.value;

    final catState = ref.watch(categoryProvider);

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
          iconTheme: IconThemeData(color: colors.textMain),
          title: Text(
            'regular_payments'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textMain,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () => _showSubscriptionDialog(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'add_subscription'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              // 👇 Додаємо перевірку на завантаження або відсутність даних
              child: (subAsync.isLoading || subState == null)
                  ? const Center(child: CircularProgressIndicator())
                  : subState.subscriptions.isEmpty
                  ? AppEmptyState(
                      icon: Icons.event_repeat_rounded,
                      title: 'no_subscriptions'.tr(),
                      subtitle: 'no_subscriptions_hint'.tr(),
                    )
                  : ListView.builder(
                      itemCount: subState.subscriptions.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        final sub = subState.subscriptions[index];
                        final bool accountExists = catState.accounts.any(
                          (c) => c.id == sub.accountId,
                        );
                        final bool expenseExists = catState.expenses.any(
                          (c) => c.id == sub.categoryId,
                        );
                        final bool isBroken = !accountExists || !expenseExists;

                        final category = catState.expenses.firstWhere(
                          (c) => c.id == sub.categoryId,
                          orElse: () => Category(
                            id: '',
                            type: CategoryType.expense,
                            name: 'unknown'.tr(),
                            icon: Icons.help_outline.codePoint,
                            bgColor: colors.iconBg.toARGB32(),
                            iconColor: colors.textSecondary.toARGB32(),
                            amount: 0,
                            isArchived: false,
                            currency: 'UAH',
                            includeInTotal: true,
                            sortOrder: 0,
                          ),
                        );

                        final Color catBgColor = Color(category.bgColor);
                        final Color catIconColor = Color(category.iconColor);

                        final IconData displayIcon =
                            sub.customIconCodePoint != null
                            ? IconHelper.getIcon(sub.customIconCodePoint!)
                            : IconHelper.getIcon(category.icon);
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final paymentDate = DateTime(
                          sub.nextPaymentDate.year,
                          sub.nextPaymentDate.month,
                          sub.nextPaymentDate.day,
                        );
                        final isDue =
                            paymentDate.isBefore(today) ||
                            paymentDate.isAtSameMomentAs(today);

                        final currencySymbol = AppCurrency.fromCode(
                          sub.currency,
                        ).symbol;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: isBroken
                                ? Border.all(
                                    color: colors.expense.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showSubscriptionDialog(
                                context,
                                subscription: sub,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: catBgColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            displayIcon,
                                            color: catIconColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sub.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.textMain,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.event,
                                                    size: 14,
                                                    color: isDue
                                                        ? colors.expense
                                                        : colors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      DateFormatter.formatFull(
                                                        sub.nextPaymentDate,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDue
                                                            ? colors.expense
                                                            : colors
                                                                  .textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '-${CurrencyFormatter.format(sub.amount)} $currencySymbol',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: colors.expense,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isDue) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.expense.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: colors.expense.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: colors.expense,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'needs_payment'.tr(),
                                                      style: TextStyle(
                                                        color: colors.expense,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 100,
                                              ),
                                              child: SizedBox(
                                                height: 32,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    backgroundColor:
                                                        colors.expense,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () async {
                                                    final (
                                                      success,
                                                      message,
                                                    ) = await ref
                                                        .read(
                                                          subscriptionProvider
                                                              .notifier,
                                                        )
                                                        .confirmSubscriptionPayment(
                                                          sub,
                                                          sub.amount,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    if (success) {
                                                      AppSnackbar.success(
                                                        context,
                                                        message,
                                                      );
                                                    } else {
                                                      AppSnackbar.error(
                                                        context,
                                                        message,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    'pay'.tr(),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
