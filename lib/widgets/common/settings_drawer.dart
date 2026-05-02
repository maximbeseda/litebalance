import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../database/app_database.dart';
import '../../screens/stats/stats_screen.dart';
import '../../screens/subscriptions_screen.dart';
import '../../screens/trash_screen.dart';
import '../../services/backup_service.dart';
import '../../screens/profile_screen.dart';
import '../../screens/currencies_screen.dart';
import '../../screens/import_export_screen.dart';
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
                final navContext = Navigator.of(context).context;
                Navigator.pop(context);

                showModalBottomSheet(
                  context: navContext,
                  backgroundColor: cardBgColor,
                  isScrollControlled: true,
                  builder: (ctx) => const _BackupBottomSheet(),
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

// ==========================================
// INLINE BOTTOM SHEET ДЛЯ БЕКАПУ
// ==========================================
enum _ExpandedMode { none, export, import }

class _BackupBottomSheet extends ConsumerStatefulWidget {
  const _BackupBottomSheet();

  @override
  ConsumerState<_BackupBottomSheet> createState() => _BackupBottomSheetState();
}

class _BackupBottomSheetState extends ConsumerState<_BackupBottomSheet> {
  _ExpandedMode _expandedMode = _ExpandedMode.none;
  bool _isObscured = true;
  bool _isLoading = false; // 👇 НОВА змінна для лоадера
  final TextEditingController _passwordCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleExpand(_ExpandedMode mode) {
    if (_isLoading) return; // Блокуємо перемикання під час завантаження
    setState(() {
      if (_expandedMode == mode) {
        _expandedMode = _ExpandedMode.none;
        _focusNode.unfocus();
      } else {
        _expandedMode = mode;
        _passwordCtrl.clear();
        _isObscured = true;
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    });
  }

  void _showSnackBar(BuildContext ctx, String message, bool isSuccess) {
    if (!ctx.mounted) return;
    final colors = Theme.of(ctx).extension<AppColorsExtension>()!;
    final accentColor = isSuccess ? colors.income : colors.expense;

    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: colors.cardBg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty || _isLoading) return;

    setState(() => _isLoading = true); // 👇 Вмикаємо лоадер

    final mode = _expandedMode;
    final rootContext = Navigator.of(context).context;

    try {
      if (mode == _ExpandedMode.export) {
        final categories = ref.read(categoryProvider).allCategoriesList;
        final transactions = ref.read(transactionProvider).value?.history ?? [];
        final subscriptions =
            ref.read(subscriptionProvider).value?.subscriptions ?? [];

        await BackupService.exportData(
          pwd,
          categories,
          transactions,
          subscriptions,
        );

        if (mounted) Navigator.pop(context); // Закриваємо тільки після успіху
        if (rootContext.mounted) {
          _showSnackBar(rootContext, 'export_success'.tr(), true);
        }
      } else if (mode == _ExpandedMode.import) {
        final db = ref.read(appDatabaseProvider);
        await BackupService.importData(pwd, db);

        if (!mounted) return;
        ref.invalidate(categoryProvider);
        ref.invalidate(transactionProvider);
        ref.invalidate(subscriptionProvider);
        ref.invalidate(statsProvider);

        Navigator.pop(context); // Закриваємо тільки після успіху
        if (rootContext.mounted) {
          _showSnackBar(rootContext, 'backup_success'.tr(), true);
        }
      }
    } catch (e) {
      // Якщо помилка — вимикаємо лоадер, щоб користувач міг спробувати ще раз
      setState(() => _isLoading = false);
      if (rootContext.mounted) {
        _showSnackBar(
          rootContext,
          e.toString().replaceAll('Exception: ', ''),
          false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Icon(Icons.upload_file, color: colors.textMain),
              title: Text(
                'export'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              subtitle: Text(
                'export_subtitle'.tr(),
                style: TextStyle(color: colors.textSecondary),
              ),
              onTap: _isLoading
                  ? null
                  : () => _toggleExpand(_ExpandedMode.export),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _expandedMode == _ExpandedMode.export
                  ? _buildInlinePasswordField(colors)
                  : const SizedBox.shrink(),
            ),

            ListTile(
              leading: Icon(Icons.download, color: colors.expense),
              title: Text(
                'import'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              subtitle: Text(
                'warning_overwrite'.tr(),
                style: TextStyle(color: colors.expense),
              ),
              onTap: _isLoading
                  ? null
                  : () => _toggleExpand(_ExpandedMode.import),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _expandedMode == _ExpandedMode.import
                  ? _buildInlinePasswordField(colors)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePasswordField(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _expandedMode == _ExpandedMode.export
                  ? 'enter_password_export'.tr()
                  : 'enter_password_import'.tr(),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextField(
            controller: _passwordCtrl,
            focusNode: _focusNode,
            obscureText: _isObscured,
            enabled: !_isLoading, // 👇 Блокуємо поле під час завантаження
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: colors.textMain, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'password'.tr(),
              hintStyle: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: colors.textSecondary,
                      size: 22,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _isObscured = !_isObscured),
                  ),
                  // 👇 ТУТ МАГІЯ ЛОАДЕРА
                  _isLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textMain,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.check_circle,
                            color: colors.textMain,
                            size: 28,
                          ),
                          onPressed: _submit,
                        ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
