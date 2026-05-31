import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/all_providers.dart';

import '../models/app_currency.dart';
import '../theme/app_colors_extension.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_pill.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/section_header.dart';
import 'lock_screen.dart';

/// Один варіант вибору для bottom-sheet пікера.
typedef _PickerItem = ({
  String value,
  String label,
  Widget? leading,
  Color color,
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _showClearDataDialog(BuildContext context) async {
    final confirmed = await AppDialog.destructive(
      context,
      title: 'clear_data_title'.tr(),
      message: 'clear_data_message'.tr(),
      icon: Icons.delete_forever_rounded,
      confirmText: 'delete'.tr(),
    );

    if (!confirmed || !context.mounted) return;

    final db = ref.read(appDatabaseProvider);
    await StorageService.wipeEntireDatabase(db);

    ref.invalidate(appDatabaseProvider);
    ref.invalidate(transactionProvider);
    ref.invalidate(categoryProvider);
    ref.invalidate(subscriptionProvider);
    ref.invalidate(statsProvider);

    ref.read(dbDirtyProvider.notifier).setDirty(true);

    if (!context.mounted) return;
    AppSnackbar.success(context, 'data_cleared_success'.tr());
  }

  /// Універсальний bottom-sheet пікер у стилі екрана категорій.
  Future<void> _showPickerSheet({
    required String title,
    required String selectedValue,
    required List<_PickerItem> items,
    required ValueChanged<String> onSelected,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
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
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool isSelected = item.value == selectedValue;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: item.leading,
                      minLeadingWidth: 0,
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? item.color : colors.textMain,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: item.color)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSelected) onSelected(item.value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openThemePicker(AppColorsExtension colors) {
    _showPickerSheet(
      title: 'interface_theme'.tr(),
      selectedValue: ref.read(themeProvider),
      items: AppTheme.allThemes.entries
          .map<_PickerItem>(
            (e) => (
              value: e.key,
              label: e.value.tr(),
              leading: null,
              color: colors.accent,
            ),
          )
          .toList(),
      onSelected: (val) => ref.read(themeProvider.notifier).setTheme(val),
    );
  }

  void _openLanguagePicker(AppColorsExtension colors) {
    _showPickerSheet(
      title: 'language'.tr(),
      selectedValue: context.locale.languageCode,
      items: context.supportedLocales
          .map<_PickerItem>(
            (locale) => (
              value: locale.languageCode,
              label:
                  AppConstants.languages[locale.languageCode] ??
                  locale.languageCode.toUpperCase(),
              leading: AppPill(
                text: locale.languageCode.toUpperCase(),
                color: colors.accent,
                width: 48,
              ),
              color: colors.accent,
            ),
          )
          .toList(),
      onSelected: (val) => context.setLocale(Locale(val)),
    );
  }

  void _openCurrencyPicker(AppColorsExtension colors) {
    _showPickerSheet(
      title: 'base_currency'.tr(),
      selectedValue: ref.read(settingsProvider).baseCurrency,
      items: AppCurrency.supportedCurrencies
          .map<_PickerItem>(
            (c) => (
              value: c.code,
              label: 'currency_names.${c.code}'.tr(),
              leading: AppPill(
                text: '${c.code}  ${c.symbol}',
                color: colors.income,
              ),
              color: colors.income,
            ),
          )
          .toList(),
      onSelected: (val) =>
          ref.read(settingsProvider.notifier).setBaseCurrency(val),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final authState = ref.watch(authControllerProvider);
    final account = authState.value;
    final isAuthLoading = authState.isLoading;

    final prefs = ref.watch(sharedPreferencesProvider);
    final isLoggedIn = prefs.getBool('has_logged_in_with_google') ?? false;

    final settings = ref.watch(settingsProvider);
    final themeId = ref.watch(themeProvider);
    final currentCurrency = AppCurrency.fromCode(settings.baseCurrency);

    return Scaffold(
      backgroundColor: colors.cardBg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: colors.textMain),
        title: Text(
          'profile'.tr(),
          style: TextStyle(
            color: colors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // --- АКАУНТ ---
            SectionHeader('account'.tr()),
            if (account == null && !isLoggedIn)
              _buildUnauthenticatedView(colors, isAuthLoading)
            else
              _buildAuthenticatedView(account, prefs, colors, settings),

            _divider(colors),

            // --- НАЛАШТУВАННЯ ДОДАТКА ---
            SectionHeader('preferences'.tr()),
            _buildPickerRow(
              colors: colors,
              icon: Icons.palette_outlined,
              title: 'interface_theme'.tr(),
              valueLabel: AppTheme.allThemes[themeId]?.tr() ?? themeId,
              valueColor: colors.textMain,
              onTap: () => _openThemePicker(colors),
            ),
            _buildPickerRow(
              colors: colors,
              icon: Icons.language_outlined,
              title: 'language'.tr(),
              valueLabel:
                  AppConstants.languages[context.locale.languageCode] ??
                  context.locale.languageCode.toUpperCase(),
              valueColor: colors.accent,
              onTap: () => _openLanguagePicker(colors),
            ),
            _buildPickerRow(
              colors: colors,
              icon: Icons.monetization_on_outlined,
              title: 'base_currency'.tr(),
              valueLabel: '${currentCurrency.code} (${currentCurrency.symbol})',
              valueColor: colors.income,
              onTap: () => _openCurrencyPicker(colors),
            ),
            _buildHapticRow(colors, prefs),

            _divider(colors),

            // --- БЕЗПЕКА ---
            const SecuritySettingsSection(),

            _divider(colors),

            // --- НЕБЕЗПЕЧНА ЗОНА ---
            _buildClearDataRow(colors),

            _divider(colors),
            Center(
              child: Text(
                '${'version'.tr()} ${ref.watch(packageInfoProvider).version}',
                style: TextStyle(
                  color: colors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColorsExtension colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, color: colors.divider),
  );

  Widget _buildUnauthenticatedView(AppColorsExtension colors, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          Text(
            'sync_promo_text'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signIn();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.cardBg,
                foregroundColor: colors.textMain,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colors.textMain,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/google.png',
                          height: 20,
                          width: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'sign_in_with_google'.tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedView(
    GoogleSignInAccount? account,
    SharedPreferences prefs,
    AppColorsExtension colors,
    SettingsState settings,
  ) {
    final String displayName =
        account?.displayName ??
        prefs.getString('google_user_name') ??
        'Google User';
    final String email =
        account?.email ?? prefs.getString('google_user_email') ?? '';
    final String? photoUrl =
        account?.photoUrl ?? prefs.getString('google_user_photo');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 300),
                        placeholder: (context, url) =>
                            _avatarFallback(displayName, colors),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : _avatarFallback(displayName, colors),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: colors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoggingOut
                    ? null
                    : () async {
                        setState(() => _isLoggingOut = true);

                        await prefs.setBool('has_logged_in_with_google', false);
                        await prefs.remove('google_user_name');
                        await prefs.remove('google_user_email');
                        await prefs.remove('google_user_photo');

                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();

                        if (mounted) setState(() => _isLoggingOut = false);
                      },
                icon: _isLoggingOut
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.expense,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                color: colors.expense,
                tooltip: 'logout'.tr(),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          visualDensity: const VisualDensity(vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          title: Text(
            'sync_only_wifi'.tr(),
            style: TextStyle(
              color: colors.textMain,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          secondary: Icon(Icons.wifi_rounded, color: colors.accent),
          value: settings.syncOnlyViaWifi,
          activeThumbColor: colors.income,
          onChanged: (val) {
            ref.read(settingsProvider.notifier).toggleSyncOnlyViaWifi(val);
          },
        ),
      ],
    );
  }

  Widget _avatarFallback(String displayName, AppColorsExtension colors) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
        style: TextStyle(
          color: colors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildPickerRow({
    required AppColorsExtension colors,
    required IconData icon,
    required String title,
    required String valueLabel,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colors.accent, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textMain,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueLabel,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHapticRow(AppColorsExtension colors, SharedPreferences prefs) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      visualDensity: const VisualDensity(vertical: -2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      title: Text(
        'haptic_feedback'.tr(),
        style: TextStyle(
          color: colors.textMain,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      secondary: Icon(Icons.vibration_rounded, color: colors.accent),
      value: prefs.getBool('haptic_feedback_enabled') ?? true,
      activeThumbColor: colors.accent,
      onChanged: (val) {
        prefs.setBool('haptic_feedback_enabled', val);
        setState(() {});
      },
    );
  }

  Widget _buildClearDataRow(AppColorsExtension colors) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(Icons.delete_forever_rounded, color: colors.expense),
        title: Text(
          'clear_all_data'.tr(),
          style: TextStyle(
            color: colors.expense,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        onTap: () async {
          final isPinSet = await SecurityService.isPinSet();

          if (isPinSet) {
            if (!mounted) return;
            final authSuccess = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const LockScreen(isSetupMode: false),
              ),
            );
            if (authSuccess != true) return;
          }

          if (!mounted) return;
          await _showClearDataDialog(context);
        },
      ),
    );
  }
}

class SecuritySettingsSection extends ConsumerStatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  ConsumerState<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState
    extends ConsumerState<SecuritySettingsSection> {
  bool _isPinSet = false;
  bool _isBiometricsEnabled = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final isPinSet = await SecurityService.isPinSet();
    final isBioEnabled = await SecurityService.isBiometricsEnabled();
    final canUseBio = await SecurityService.canUseBiometrics();

    if (mounted) {
      setState(() {
        _isPinSet = isPinSet;
        _isBiometricsEnabled = isBioEnabled;
        _canUseBiometrics = canUseBio;
      });
    }
  }

  Future<void> _togglePin(bool enable) async {
    if (enable) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen(isSetupMode: true)),
      );
      if (success == true) {
        await ref
            .read(sharedPreferencesProvider)
            .setBool('pin_set_cache', true);
        await _loadSecuritySettings();
      }
    } else {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen(isSetupMode: false)),
      );
      if (success == true) {
        await SecurityService.disableSecurity();
        await ref
            .read(sharedPreferencesProvider)
            .setBool('pin_set_cache', false);
        await _loadSecuritySettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('security'.tr()),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          visualDensity: const VisualDensity(vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          title: Text(
            'pin_code'.tr(),
            style: TextStyle(
              color: colors.textMain,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          secondary: Icon(Icons.lock_outline, color: colors.accent),
          value: _isPinSet,
          activeThumbColor: colors.accent,
          onChanged: _togglePin,
        ),
        if (_isPinSet && _canUseBiometrics)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            visualDensity: const VisualDensity(vertical: -2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            title: Text(
              'biometrics'.tr(),
              style: TextStyle(
                color: colors.textMain,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            secondary: Icon(Icons.fingerprint, color: colors.accent),
            value: _isBiometricsEnabled,
            activeThumbColor: colors.accent,
            onChanged: (val) async {
              await SecurityService.setBiometricsEnabled(val);
              await _loadSecuritySettings();
            },
          ),
      ],
    );
  }
}
