import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/all_providers.dart';

import '../models/app_currency.dart';
import '../theme/app_colors_extension.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';
import 'lock_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showClearDataDialog(BuildContext context, WidgetRef ref) async {
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

      ref.invalidate(transactionProvider);
      ref.invalidate(categoryProvider);
      ref.invalidate(subscriptionProvider);
      ref.invalidate(statsProvider);

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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

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
                          ListTile(
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
                              final isPinSet = await SecurityService.isPinSet();

                              if (isPinSet) {
                                if (!context.mounted) return;

                                final authSuccess = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LockScreen(isSetupMode: false),
                                  ),
                                );

                                if (authSuccess != true) {
                                  return;
                                }
                              }

                              if (!context.mounted) return;

                              await _showClearDataDialog(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 👇 ДОДАНО: Версія прибита до нижнього краю екрана
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

  Widget _buildSettingsRow({
    required AppColorsExtension colors,
    required IconData icon,
    required String title,
    required String dropdownValue,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return ListTile(
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
              SwitchListTile(
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
              if (_isPinSet && _canUseBiometrics) ...[
                Divider(
                  height: 1,
                  color: colors.textSecondary.withValues(alpha: 0.1),
                ),
                SwitchListTile(
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
