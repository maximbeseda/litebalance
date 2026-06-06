import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/app_colors_extension.dart';
import '../providers/all_providers.dart';
import '../services/backup_service.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/section_header.dart';

class BackupManagementScreen extends ConsumerStatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  ConsumerState<BackupManagementScreen> createState() =>
      _BackupManagementScreenState();
}

class _BackupManagementScreenState
    extends ConsumerState<BackupManagementScreen> {
  bool _isLoading = false;
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  // --- UI КОМПОНЕНТИ (ДІАЛОГИ ТА ШИТИ) ---

  void _showStatus(String message, bool isSuccess) {
    if (!mounted) return;
    if (isSuccess) {
      AppSnackbar.success(context, message);
    } else {
      AppSnackbar.error(context, message);
    }
  }

  // СУЧАСНИЙ BOTTOM SHEET ДЛЯ ПАРОЛЯ
  Future<String?> _showPasswordBottomSheet({
    required String title,
    required String description, // Додаємо опис як параметр
  }) async {
    _passwordCtrl.clear();
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    bool obscureText = true;

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // --- ЗАГОЛОВОК ---
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // --- ПОЯСНЕННЯ (Subtitle) ---
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height:
                        1.4, // Збільшуємо міжрядковий інтервал для читабельності
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: obscureText,
                  autofocus: true,
                  style: TextStyle(color: colors.textMain),
                  decoration: InputDecoration(
                    hintText: 'password'.tr(),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: colors.textSecondary,
                      ),
                      onPressed: () =>
                          setModalState(() => obscureText = !obscureText),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: Text(
                          'cancel'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, _passwordCtrl.text),
                        child: Text(
                          'confirm'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ДІАЛОГ ПІДТВЕРДЖЕННЯ
  Future<bool> _confirmRestore(String message) {
    return AppDialog.destructive(
      context,
      title: 'warning_overwrite'.tr(),
      message: message,
      confirmText: 'confirm'.tr(),
      barrierDismissible: false,
    );
  }

  // --- ЛОГІКА РОБОТИ ---

  void _refreshAllData() {
    ref.invalidate(appDatabaseProvider);
    ref.invalidate(categoryProvider);
    ref.invalidate(transactionProvider);
    ref.invalidate(subscriptionProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(settingsProvider);
    ref.read(dbDirtyProvider.notifier).setDirty(true);
  }

  Future<void> _runCloudBackup() async {
    setState(() => _isLoading = true);
    final service = ref.read(driveBackupServiceProvider);
    final success = await service.backupDatabase(ref.read(appDatabaseProvider));

    if (!mounted) return;
    if (success) {
      await ref.read(settingsProvider.notifier).updateCloudBackupTime();
      if (!mounted) return;
      _showStatus('cloud_backup_success'.tr(), true);
    } else {
      _showStatus('cloud_backup_error'.tr(), false);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _runCloudRestore() async {
    final confirmed = await _confirmRestore('cloud_restore_confirm'.tr());
    if (!confirmed) return;

    setState(() => _isLoading = true);
    final service = ref.read(driveBackupServiceProvider);
    final success = await service.restoreDatabase(
      ref.read(appDatabaseProvider),
    );

    if (!mounted) return;
    if (success) {
      _refreshAllData();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _showStatus('backup_success'.tr(), true);
    } else {
      _showStatus('cloud_backup_error'.tr(), false);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _runFileExport() async {
    final pwd = await _showPasswordBottomSheet(
      title: 'backup_protection_title'.tr(),
      description: 'export_password_hint'.tr(),
    );
    if (pwd == null) return;

    if (pwd.isEmpty) {
      _showStatus('enter_password_error'.tr(), false);
      return;
    }

    setState(() => _isLoading = true);
    try {
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

      if (!mounted) return;
      await ref.read(settingsProvider.notifier).updateFileBackupTime();
      if (!mounted) return;
      _showStatus('export_success'.tr(), true);
    } catch (e) {
      if (!mounted) return;
      _showStatus(e.toString().replaceAll('Exception: ', ''), false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ОНОВЛЕНА ЛОГІКА ІМПОРТУ (Пароль ПІСЛЯ вибору файлу)
  Future<void> _runFileImport() async {
    try {
      // 1. Викликаємо сервіс для вибору файлу
      final selectedFile = await BackupService.pickBackupFile();
      if (selectedFile == null) return; // Користувач скасував вибір

      // 2. Тепер запитуємо пароль через Bottom Sheet
      if (!mounted) return;
      final pwd = await _showPasswordBottomSheet(
        title: 'unlock_backup_title'.tr(),
        description: 'import_password_hint'.tr(),
      );
      if (pwd == null) return;

      if (pwd.isEmpty) {
        _showStatus('enter_password_error'.tr(), false);
        return;
      }

      // 3. Підтвердження заміни бази
      if (!mounted) return;
      final confirmed = await _confirmRestore('warning_overwrite'.tr());
      if (!confirmed) return;

      // 4. Починаємо імпорт
      setState(() => _isLoading = true);
      final db = ref.read(appDatabaseProvider);

      // Передаємо файл та пароль у сервіс імпорту
      await BackupService.importDataFromFile(selectedFile, pwd, db);

      if (!mounted) return;
      _refreshAllData();
      _showStatus('backup_success'.tr(), true);
    } catch (e) {
      if (!mounted) return;
      _showStatus(e.toString().replaceAll('Exception: ', ''), false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final SettingsState settings = ref.watch(settingsProvider);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return PopScope(
      canPop: !_isLoading,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: colors.cardBg,
            appBar: AppBar(
              iconTheme: IconThemeData(color: colors.textMain),
              title: Text(
                'backup_title'.tr(),
                style: TextStyle(
                  color: colors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              backgroundColor: colors.cardBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                children: [
                  SectionHeader('google_drive_backup'.tr()),
                  _buildActionRow(
                    colors: colors,
                    icon: Icons.cloud_upload_outlined,
                    title: 'sync_with_cloud'.tr(),
                    subtitle: settings.lastCloudBackup != null
                        ? '${'last_backup'.tr()}: ${df.format(settings.lastCloudBackup!)}'
                        : 'no_backups_yet'.tr(),
                    iconColor: colors.accent,
                    onTap: _runCloudBackup,
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: colors.divider,
                  ),
                  _buildActionRow(
                    colors: colors,
                    icon: Icons.cloud_download_outlined,
                    title: 'import_from_cloud'.tr(),
                    subtitle: 'warning_overwrite'.tr(),
                    iconColor: colors.expense,
                    onTap: _runCloudRestore,
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: colors.divider),
                  const SizedBox(height: 8),
                  SectionHeader('file_backup'.tr()),
                  _buildActionRow(
                    colors: colors,
                    icon: Icons.upload_file_outlined,
                    title: 'export_to_file'.tr(),
                    subtitle: settings.lastFileBackup != null
                        ? '${'last_backup'.tr()}: ${df.format(settings.lastFileBackup!)}'
                        : 'no_backups_yet'.tr(),
                    iconColor: colors.income,
                    onTap: _runFileExport,
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: colors.divider,
                  ),
                  _buildActionRow(
                    colors: colors,
                    icon: Icons.download_outlined,
                    title: 'import_from_file'.tr(),
                    subtitle: 'warning_overwrite'.tr(),
                    iconColor: colors.expense,
                    onTap: _runFileImport,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // --- ДОПОМІЖНІ ВІДЖЕТИ ---
  Widget _buildActionRow({
    required AppColorsExtension colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color:
          Colors.transparent, // 👈 Додаємо прозоре полотно для анімацій кліку
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: iconColor ?? colors.textMain),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: colors.textSecondary.withValues(alpha: 0.3),
          size: 16,
        ),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }
}
