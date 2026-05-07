import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../screens/stats/stats_screen.dart';
import '../../screens/subscriptions_screen.dart';
import '../../screens/trash_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/currencies_screen.dart';
import '../../screens/import_export_screen.dart';
import '../../screens/backup_management_screen.dart';
import '../../theme/app_colors_extension.dart';

// 👇 Імпортуємо наш хаб провайдерів
import '../../providers/all_providers.dart';

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Отримуємо кольори безпечно
    final colors = Theme.of(context).extension<AppColorsExtension>();

    // Отримуємо асинхронні стани
    final subAsync = ref.watch(subscriptionProvider);
    final txAsync = ref.watch(transactionProvider);

    final subState = subAsync.value;
    final txState = txAsync.value;

    final hasPendingSubscriptions = subState?.hasPendingPayments ?? false;

    // Рахуємо елементи в кошику (безпечно, якщо дані ще вантажаться)
    final deletedCatsCount = ref
        .watch(categoryProvider)
        .deletedCategories
        .length;
    final deletedTxsCount = txState?.deletedHistory.length ?? 0;
    final deletedSubsCount = subState?.deletedSubscriptions.length ?? 0;

    final totalTrashCount =
        deletedCatsCount + deletedTxsCount + deletedSubsCount;

    // Фолбеки для кольорів, щоб не було Null error
    final textMainColor = colors?.textMain ?? Colors.black;
    final textSecondaryColor = colors?.textSecondary ?? Colors.grey;
    final cardBgColor = colors?.cardBg ?? Colors.white;
    final iconBgColor = colors?.iconBg ?? Colors.grey.shade200;

    return Drawer(
      backgroundColor: cardBgColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // --- ШАПКА ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'settings'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textMainColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.settings_outlined, color: textSecondaryColor),
                ],
              ),
            ),
            Divider(color: iconBgColor, height: 1),

            // КНОПКА ПРОФІЛЮ
            ListTile(
              leading: Icon(Icons.person_outline, color: textMainColor),
              title: Text(
                'profile'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            // КНОПКА СТАТИСТИКИ
            ListTile(
              leading: Icon(Icons.pie_chart_outline, color: textMainColor),
              title: Text(
                'statistics'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),

            // КНОПКА КУРСИ ВАЛЮТ
            ListTile(
              leading: Icon(Icons.currency_exchange, color: textMainColor),
              title: Text(
                'exchange_rates'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CurrenciesScreen(),
                  ),
                );
              },
            ),

            // КНОПКА ЕКСПОРТУ/ІМПОРТУ (CSV)
            ListTile(
              leading: Icon(Icons.import_export, color: textMainColor),
              title: Text(
                'data_management'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportExportScreen(),
                  ),
                );
              },
            ),

            // КНОПКА БЕКАПУ
            ListTile(
              leading: Icon(Icons.save_alt_rounded, color: textMainColor),
              title: Text(
                'backup_title'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              onTap: () {
                // Спочатку закриваємо сам Drawer
                Navigator.pop(context);

                // Переходимо на новий повноцінний екран
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackupManagementScreen(),
                  ),
                );
              },
            ),

            // КНОПКА ПІДПИСОК
            ListTile(
              leading: Icon(Icons.autorenew, color: textMainColor),
              title: Text(
                'regular_payments'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              trailing: hasPendingSubscriptions
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors?.expense ?? Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (colors?.expense ?? Colors.red).withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionsScreen(),
                  ),
                );
              },
            ),

            // КНОПКА КОШИКА
            ListTile(
              leading: Icon(Icons.delete_outline, color: textMainColor),
              title: Text(
                'trash'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMainColor,
                ),
              ),
              trailing: totalTrashCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (colors?.expense ?? Colors.red).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        totalTrashCount.toString(),
                        style: TextStyle(
                          color: colors?.expense ?? Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrashScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
