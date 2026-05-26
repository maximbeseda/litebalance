import 'dart:async';
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
import 'lock_screen.dart';

// 👇 1. Змінили на ConsumerStatefulWidget для локального стану завантаження
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // 👇 2. Стан для кнопки логауту
  bool _isLoggingOut = false;

  Future<void> _showClearDataDialog(BuildContext context) async {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: colors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.expense.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: colors.expense,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'clear_data_title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'clear_data_message'.tr(),
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'cancel'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.expense,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'delete'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        ) ??
        false;

    if (confirmed) {
      final db = ref.read(appDatabaseProvider);

      await StorageService.wipeEntireDatabase(db);

      ref.invalidate(appDatabaseProvider);
      ref.invalidate(transactionProvider);
      ref.invalidate(categoryProvider);
      ref.invalidate(subscriptionProvider);
      ref.invalidate(statsProvider);

      ref.read(dbDirtyProvider.notifier).setDirty(true);

      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.cardBg,
          elevation: 4,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.income, width: 1.0),
          ),
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.income, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'data_cleared_success'.tr(),
                  style: TextStyle(
                    color: colors.textMain,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final authState = ref.watch(authControllerProvider);
    final account = authState.value;
    final isAuthLoading = authState.isLoading;

    final prefs = ref.watch(sharedPreferencesProvider);
    final isLoggedIn = prefs.getBool('has_logged_in_with_google') ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: IconThemeData(color: colors.textMain),
        title: Text(
          'profile'.tr(),
          style: TextStyle(
            color: colors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.bgGradientStart, colors.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (account == null && !isLoggedIn)
                            _buildUnauthenticatedView(colors, isAuthLoading)
                          else
                            _buildAuthenticatedView(account, prefs, colors),

                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: colors.textSecondary.withValues(alpha: 0.1),
                          ),

                          // Тема
                          _buildSettingsRow(
                            colors: colors,
                            icon: Icons.palette_outlined,
                            title: 'interface_theme'.tr(),
                            dropdownValue: ref.watch(themeProvider),
                            items: AppTheme.allThemes.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  entry.value.tr(),
                                  style: TextStyle(color: colors.textMain),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(themeProvider.notifier).setTheme(val);
                              }
                            },
                          ),

                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: colors.textSecondary.withValues(alpha: 0.1),
                          ),

                          // Мова
                          _buildSettingsRow(
                            colors: colors,
                            icon: Icons.language_outlined,
                            title: 'language'.tr(),
                            dropdownValue: context.locale.languageCode,
                            items: context.supportedLocales.map((locale) {
                              return DropdownMenuItem(
                                value: locale.languageCode,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  AppConstants.languages[locale.languageCode] ??
                                      locale.languageCode.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => val != null
                                ? context.setLocale(Locale(val))
                                : null,
                          ),

                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: colors.textSecondary.withValues(alpha: 0.1),
                          ),

                          // Валюта
                          _buildSettingsRow(
                            colors: colors,
                            icon: Icons.monetization_on_outlined,
                            title: 'base_currency'.tr(),
                            dropdownValue: ref
                                .watch(settingsProvider)
                                .baseCurrency,
                            items: AppCurrency.supportedCurrencies.map((
                              currency,
                            ) {
                              return DropdownMenuItem(
                                value: currency.code,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${currency.code} (${currency.symbol})',
                                  style: TextStyle(
                                    color: colors.income,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setBaseCurrency(val);
                              }
                            },
                          ),

                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: colors.textSecondary.withValues(alpha: 0.1),
                          ),

                          const SecuritySettingsSection(),

                          // Кнопка очищення даних
                          Material(
                            color: Colors
                                .transparent, // 👈 Додаємо прозорий Material
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Icon(
                                Icons.delete_forever_rounded,
                                color: colors.expense,
                              ),
                              title: Text(
                                'clear_all_data'.tr(),
                                style: TextStyle(
                                  color: colors.expense,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onTap: () async {
                                final isPinSet =
                                    await SecurityService.isPinSet();

                                if (isPinSet) {
                                  if (!context.mounted) return;

                                  final authSuccess =
                                      await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LockScreen(
                                            isSetupMode: false,
                                          ),
                                        ),
                                      );

                                  if (authSuccess != true) {
                                    return;
                                  }
                                }

                                if (!context.mounted) return;

                                await _showClearDataDialog(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Версія прибита до нижнього краю екрана
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                child: Text(
                  'v${ref.watch(packageInfoProvider).version}',
                  style: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedView(AppColorsExtension colors, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'sync_promo_text'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final authNotifier = ref.read(
                        authControllerProvider.notifier,
                      );
                      await authNotifier.signIn();
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
  ) {
    final settings = ref.watch(settingsProvider);

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
          padding: const EdgeInsets.all(16.0),
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
                        fadeInDuration: const Duration(
                          milliseconds: 300,
                        ), // Плавна поява
                        placeholder: (context, url) => Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'G',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
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
              // 👇 3. Оновлена кнопка логауту з індикатором та швидким очищенням кешу
              IconButton(
                onPressed: _isLoggingOut
                    ? null
                    : () async {
                        setState(() {
                          _isLoggingOut = true;
                        });

                        // Миттєво стираємо кеш ДО логауту,
                        // щоб екран відразу перебудувався правильно після завершення запиту.
                        await prefs.setBool('has_logged_in_with_google', false);
                        await prefs.remove('google_user_name');
                        await prefs.remove('google_user_email');
                        await prefs.remove('google_user_photo');

                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();

                        if (mounted) {
                          setState(() {
                            _isLoggingOut = false;
                          });
                        }
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

        Divider(height: 1, color: colors.textSecondary.withValues(alpha: 0.1)),

        Material(
          color: Colors.transparent, // 👈 Додаємо прозорий Material
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 0,
            ),
            title: Text(
              'sync_only_wifi'.tr(),
              style: TextStyle(
                color: colors.textMain,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            secondary: Icon(Icons.wifi_rounded, color: colors.textMain),
            value: settings.syncOnlyViaWifi,
            activeThumbColor: colors.income,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleSyncOnlyViaWifi(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRow({
    required AppColorsExtension colors,
    required IconData icon,
    required String title,
    required String dropdownValue,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Material(
      color: Colors.transparent, // 👈 Додаємо прозорий Material
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: colors.textMain),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 115,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownValue,
              dropdownColor: colors.cardBg,
              borderRadius: BorderRadius.circular(8),
              alignment: Alignment.centerRight,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: colors.textSecondary,
                size: 20,
              ),
              onChanged: onChanged,
              items: items,
            ),
          ),
        ),
      ),
    );
  }
}

class SecuritySettingsSection extends StatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  State<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<SecuritySettingsSection> {
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
      if (success == true) await _loadSecuritySettings();
    } else {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen(isSetupMode: false)),
      );
      if (success == true) {
        await SecurityService.disableSecurity();
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
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
          child: Text(
            'security'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Material(
                // 👈 Додаємо Material
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    'pin_code'.tr(),
                    style: TextStyle(
                      color: colors.textMain,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  secondary: Icon(Icons.lock_outline, color: colors.textMain),
                  value: _isPinSet,
                  activeThumbColor: colors.accent,
                  onChanged: _togglePin,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_isPinSet && _canUseBiometrics) ...[
                Divider(
                  height: 1,
                  color: colors.textSecondary.withValues(alpha: 0.1),
                ),
                Material(
                  // 👈 Додаємо Material
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      'biometrics'.tr(),
                      style: TextStyle(
                        color: colors.textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    secondary: Icon(Icons.fingerprint, color: colors.textMain),
                    value: _isBiometricsEnabled,
                    activeThumbColor: colors.accent,
                    onChanged: (val) async {
                      await SecurityService.setBiometricsEnabled(val);
                      await _loadSecuritySettings();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
