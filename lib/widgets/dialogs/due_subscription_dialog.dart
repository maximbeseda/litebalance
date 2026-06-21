import 'package:flutter/material.dart';
// 👇 1. Замінили provider на flutter_riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

// 👇 2. Імпортуємо наш хаб провайдерів
import '../../providers/all_providers.dart';

import '../../models/app_currency.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/amount_text.dart';
import '../../utils/currency_formatter.dart';
import '../common/app_snackbar.dart';

// 👇 3. Змінили StatelessWidget на ConsumerWidget
class DueSubscriptionDialog extends ConsumerWidget {
  final Subscription subscription;

  const DueSubscriptionDialog({super.key, required this.subscription});

  String _getFormattedDate(BuildContext context) {
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return DateFormat.yMMMMd(languageCode).format(subscription.nextPaymentDate);
  }

  @override
  // 👇 4. Додали WidgetRef ref
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 5. Отримуємо дані з провайдерів через ref
    final catState = ref.watch(categoryProvider);
    ref.watch(
      settingsProvider,
    ); // Стежимо за змінами налаштувань для перерахунку балансу
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final account = catState.allCategoriesList
        .where((c) => c.id == subscription.accountId)
        .firstOrNull;

    bool canPay = false;
    if (account != null && !account.isArchived) {
      // Конвертуємо в базову валюту і округлюємо до цілих копійок
      final int accountAmountBase = settingsNotifier.convertToBase(
        account.amount,
        account.currency,
      );

      final int subAmountBase = settingsNotifier.convertToBase(
        subscription.amount,
        subscription.currency,
      );

      canPay = accountAmountBase >= subAmountBase;
    }

    final currencySymbol = AppCurrency.fromCode(subscription.currency).symbol;

    return Dialog(
      backgroundColor: colors.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. ІКОНКА
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (canPay ? colors.income : colors.expense)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      canPay
                          ? Icons.account_balance_wallet_rounded
                          : Icons.money_off_rounded,
                      color: canPay ? colors.income : colors.expense,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ЗАГОЛОВОК
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'regular_payment_title'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.textMain,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.payments_outlined,
                        color: colors.textMain,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. ПІДЗАГОЛОВОК
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textSecondary,
                      ),
                      children: [
                        TextSpan(text: 'time_to_pay'.tr()),
                        TextSpan(
                          text: subscription.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. ДАТА
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getFormattedDate(context),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textMain,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. СУМА
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AmountText(
                      amount: CurrencyFormatter.format(
                        subscription.amount,
                        currencyCode: subscription.currency,
                      ),
                      symbol: currencySymbol,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                        color: canPay ? colors.textMain : colors.expense,
                      ),
                    ),
                  ),

                  if (!canPay) ...[
                    const SizedBox(height: 8),
                    Text(
                      account == null || account.isArchived
                          ? 'error_category_deleted'.tr()
                          : 'not_enough_funds'.tr(args: [account.name]),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 6. КНОПКИ
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            // 👇 ВИПРАВЛЕНО: Закриваємо діалог миттєво
                            Navigator.pop(context);
                            await ref
                                .read(subscriptionProvider.notifier)
                                .skipSubscriptionPayment(subscription);
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'skip'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: canPay
                                ? colors.textMain
                                : colors.expense,
                            foregroundColor: colors.cardBg,
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final subNotifier = ref.read(
                              subscriptionProvider.notifier,
                            );

                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );

                            if (!canPay) {
                              await subNotifier.ignoreSubscriptionPermanently(
                                subscription.id,
                              );
                              navigator.pop();
                              return;
                            }

                            // 👇 ВИПРАВЛЕНО: Закриваємо діалог ДО початку оплати,
                            // щоб уникнути його повторного відкриття через зміну стану
                            navigator.pop();

                            final (success, message) = await subNotifier
                                .confirmSubscriptionPayment(
                                  subscription,
                                  subscription.amount,
                                );

                            // Показуємо Snackbar на головному екрані
                            // (контекст ScaffoldMessenger лишається валідним
                            // після закриття діалогу)
                            if (success) {
                              AppSnackbar.success(
                                scaffoldMessenger.context,
                                message,
                              );
                            } else {
                              AppSnackbar.error(
                                scaffoldMessenger.context,
                                message,
                              );
                            }
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              canPay ? 'pay'.tr() : 'pay_later'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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

          // Хрестик закриття
          Positioned(
            right: 16,
            top: 16,
            child: GestureDetector(
              onTap: () {
                // 👇 ВИПРАВЛЕНО: Закриваємо діалог миттєво
                Navigator.pop(context);
                ref
                    .read(subscriptionProvider.notifier)
                    .ignoreSubscriptionForSession(subscription.id);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: colors.textMain, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
