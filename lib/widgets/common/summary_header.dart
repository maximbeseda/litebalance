import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/all_providers.dart';
import '../../utils/currency_formatter.dart';
import 'rolling_digit.dart';
import '../../theme/app_colors_extension.dart';
import '../../models/app_currency.dart';
import 'animated_dots.dart';

class SummaryHeader extends ConsumerWidget {
  final int totalBalance;
  final int totalIncomes;
  final int totalExpenses;
  final VoidCallback onBalanceTap;
  final VoidCallback onIncomesTap;
  final VoidCallback onExpensesTap;
  final VoidCallback onSettingsTap;
  final bool isMigrating;

  const SummaryHeader({
    super.key,
    required this.totalBalance,
    required this.totalIncomes,
    required this.totalExpenses,
    required this.onBalanceTap,
    required this.onIncomesTap,
    required this.onExpensesTap,
    required this.onSettingsTap,
    this.isMigrating = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final settingsState = ref.watch(settingsProvider);
    final baseCurrencySymbol = AppCurrency.fromCode(
      settingsState.baseCurrency,
    ).symbol;

    // 👇 ВИПРАВЛЕНО: Отримуємо AsyncValue і безпечно дістаємо значення через .value
    final subAsync = ref.watch(subscriptionProvider);
    final hasPendingSubscriptions = subAsync.value?.hasPendingPayments ?? false;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 10, top: 15, bottom: 0),
        child: Row(
          children: [
            _item(
              Icons.account_balance_wallet_outlined,
              totalBalance,
              colors.textMain,
              onBalanceTap,
              colors,
              baseCurrencySymbol,
            ),
            _item(
              Icons.north_east,
              totalIncomes,
              colors.income,
              onIncomesTap,
              colors,
              baseCurrencySymbol,
            ),
            _item(
              Icons.south_east,
              totalExpenses,
              colors.expense,
              onExpensesTap,
              colors,
              baseCurrencySymbol,
            ),

            GestureDetector(
              onTap: onSettingsTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 24,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    if (hasPendingSubscriptions)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.expense,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.expense.withValues(alpha: 0.4),
                                blurRadius: 3,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    int amount,
    Color color,
    VoidCallback onTap,
    AppColorsExtension colors,
    String currencySymbol,
  ) {
    final String formattedAmount = CurrencyFormatter.format(amount, isHeader: true);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Opacity(
                      opacity: isMigrating ? 0.0 : 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        // Цифри суми — окремі віджети в Row; у RTL-локалях Row
                        // реверсує дітей, тож фіксуємо порядок зліва направо.
                        textDirection: TextDirection.ltr,
                        children: [
                          for (int i = 0; i < formattedAmount.length; i++)
                            RollingDigit(
                              char: formattedAmount[i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          Text(
                            ' $currencySymbol',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMigrating)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedDots(
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
