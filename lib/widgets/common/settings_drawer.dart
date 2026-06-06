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
import '../../utils/app_page_route.dart';
import 'category_halo_icon.dart';

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
    final cardBgColor = colors?.cardBg ?? Colors.white;
    final iconBgColor = colors?.iconBg ?? Colors.grey.shade200;
    final menuIconColor = colors?.accent ?? Colors.blueAccent;
    final expenseColor = colors?.expense ?? Colors.red;

    return Drawer(
      backgroundColor: cardBgColor,
      child: SafeArea(
        // Column, щоб прибити синхронізацію донизу
        child: Column(
          children: [
            Expanded(
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
                        CategoryHaloIcon(
                          icon: Icons.settings_outlined,
                          bgColor: menuIconColor,
                          iconColor: Colors.white,
                          size: 52,
                        ),
                      ],
                    ),
                  ),
                  Divider(color: iconBgColor, height: 1),
                  const SizedBox(height: 4),

                  // ПРОФІЛЬ
                  _buildMenuTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'profile'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    screenBuilder: () => const ProfileScreen(),
                  ),

                  // СТАТИСТИКА
                  _buildMenuTile(
                    context,
                    icon: Icons.pie_chart_outline,
                    title: 'statistics'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    screenBuilder: () => const StatsScreen(),
                  ),

                  // РЕГУЛЯРНІ ПЛАТЕЖІ
                  _buildMenuTile(
                    context,
                    icon: Icons.autorenew,
                    title: 'regular_payments'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    trailing: hasPendingSubscriptions
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: expenseColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: expenseColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          )
                        : null,
                    screenBuilder: () => const SubscriptionsScreen(),
                  ),

                  // КУРСИ ВАЛЮТ
                  _buildMenuTile(
                    context,
                    icon: Icons.currency_exchange,
                    title: 'exchange_rates'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    screenBuilder: () => const CurrenciesScreen(),
                  ),

                  // УПРАВЛІННЯ ДАНИМИ (CSV)
                  _buildMenuTile(
                    context,
                    icon: Icons.import_export,
                    title: 'data_management'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    screenBuilder: () => const ImportExportScreen(),
                  ),

                  // РЕЗЕРВНЕ КОПІЮВАННЯ
                  _buildMenuTile(
                    context,
                    icon: Icons.save_alt_rounded,
                    title: 'backup_title'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    screenBuilder: () => const BackupManagementScreen(),
                  ),

                  // КОШИК
                  _buildMenuTile(
                    context,
                    icon: Icons.delete_outline,
                    title: 'trash'.tr(),
                    iconColor: menuIconColor,
                    textColor: textMainColor,
                    trailing: totalTrashCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: expenseColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              totalTrashCount.toString(),
                              style: TextStyle(
                                color: expenseColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    screenBuilder: () => const TrashScreen(),
                  ),
                ],
              ),
            ),

            // Секція синхронізації в самому низу
            Divider(color: iconBgColor, height: 1),
            _buildSyncStatusRow(context, ref, colors),
          ],
        ),
      ),
    );
  }

  // Єдиний пункт бокового меню: кольорова іконка + назва + опційний трейлінг.
  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required Widget Function() screenBuilder,
    Widget? trailing,
  }) {
    return ListTile(
      visualDensity: const VisualDensity(vertical: -1),
      minLeadingWidth: 0,
      horizontalTitleGap: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, appPageRoute(screenBuilder()));
      },
    );
  }

  // Метод для відображення статусу синхронізації
  Widget _buildSyncStatusRow(
    BuildContext context,
    WidgetRef ref,
    AppColorsExtension? colors,
  ) {
    // Отримуємо дату з поточних налаштувань
    final settings = ref.watch(settingsProvider);
    final lastSyncDate = settings.lastCloudBackup;
    final lastSyncStr = lastSyncDate != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(lastSyncDate)
        : 'never'.tr();

    // Підключаємо реальний стан
    final syncState = ref.watch(syncControllerProvider);
    final bool isSyncError = syncState.hasError;
    final bool isSyncing = syncState.isSyncing;

    final textColor = isSyncError
        ? (colors?.expense ?? Colors.red)
        : (colors?.textMain ?? Colors.black);
    final subtitleColor = isSyncError
        ? (colors?.expense ?? Colors.red).withValues(alpha: 0.8)
        : (colors?.textSecondary ?? Colors.grey);
    final iconColor = isSyncError
        ? (colors?.expense ?? Colors.red)
        : (colors?.textMain ?? Colors.black);

    // Хмаринка: світлоголуба у нормі, червона при помилці (разом з текстом).
    final cloudColor = isSyncError
        ? (colors?.expense ?? Colors.red)
        : const Color(0xFF4FC3F7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(
            isSyncError ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            color: cloudColor,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'last_sync'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (isSyncError) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors?.expense ?? Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastSyncStr,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isSyncing
                ? null
                : () async {
                    // Запускаємо реальну синхронізацію
                    await ref.read(syncControllerProvider.notifier).syncNow();
                  },
            icon: isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    isSyncError
                        ? Icons.sync_problem_rounded
                        : Icons.sync_rounded,
                    color: iconColor,
                  ),
            tooltip: 'sync_now'.tr(),
          ),
        ],
      ),
    );
  }
}
