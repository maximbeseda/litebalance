import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/all_providers.dart';
import '../services/storage_service.dart';
import '../services/default_categories_service.dart';
import '../models/app_currency.dart';
import '../utils/app_constants.dart';
import '../theme/app_colors_extension.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_pill.dart';
import '../widgets/common/app_picker_sheet.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_logo.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late TextEditingController _currencyCtrl;
  late TextEditingController _languageCtrl;

  String _selectedCurrencyCode = 'USD';
  bool _isSaving = false;
  bool _isInitialized = false;

  // Єдине джерело мов — [AppConstants.languages]. «short» — це код у верхньому
  // регістрі (UK, EN, …), тож не дублюємо назви тут.
  final List<Map<String, String>> _supportedLanguages = [
    for (final e in AppConstants.languages.entries)
      {'code': e.key, 'name': e.value, 'short': e.key.toUpperCase()},
  ];

  @override
  void initState() {
    super.initState();
    _currencyCtrl = TextEditingController();
    _languageCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      _autoDetectDefaults();
      _isInitialized = true;
    }
  }

  void _autoDetectDefaults() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    final deviceLangCode = deviceLocale.languageCode;
    final deviceCountryCode = deviceLocale.countryCode ?? '';

    final initialLang = _supportedLanguages.firstWhere(
      (lang) => lang['code'] == deviceLangCode,
      orElse: () =>
          _supportedLanguages.firstWhere((lang) => lang['code'] == 'en'),
    );

    String initialCurrency = 'USD';

    final Map<String, String> countryToCurrency = {
      'UA': 'UAH',
      'US': 'USD',
      'GB': 'GBP',
      'PL': 'PLN',
      'CA': 'CAD',
      'AU': 'AUD',
      'JP': 'JPY',
      'CH': 'CHF',
      'DE': 'EUR',
      'FR': 'EUR',
      'IT': 'EUR',
      'ES': 'EUR',
      'NL': 'EUR',
      'AT': 'EUR',
      'BE': 'EUR',
      'FI': 'EUR',
      'IE': 'EUR',
      'PT': 'EUR',
      'GR': 'EUR',
    };

    if (countryToCurrency.containsKey(deviceCountryCode)) {
      initialCurrency = countryToCurrency[deviceCountryCode]!;
    } else {
      if (initialLang['code'] == 'uk') initialCurrency = 'UAH';
      if (initialLang['code'] == 'de') initialCurrency = 'EUR';
    }

    final bool isCurrencySupported = AppCurrency.supportedCurrencies.any(
      (c) => c.code == initialCurrency,
    );
    if (!isCurrencySupported) {
      initialCurrency = 'USD';
    }

    _selectedCurrencyCode = initialCurrency;
    _currencyCtrl.text = 'currency_names.$initialCurrency'.tr();
    _languageCtrl.text = initialLang['name']!;

    if (context.locale.languageCode != initialLang['code']) {
      final code = initialLang['code']!;
      Future.microtask(() {
        if (mounted) {
          context.setLocale(Locale(code));
        }
      });
    }
  }

  @override
  void dispose() {
    _currencyCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  // Завершення онбордингу та перехід на головний екран
  void _finishOnboarding() async {
    setState(() => _isSaving = true);

    // Отримуємо languageCode з context ДО будь-яких await
    final languageCode = context.locale.languageCode;

    final settingsNotifier = ref.read(settingsProvider.notifier);
    await settingsNotifier.setBaseCurrency(_selectedCurrencyCode);

    // 👇 ДОДАНО: Створюємо базові категорії якщо база порожня
    final db = ref.read(appDatabaseProvider);
    await DefaultCategoriesService.createDefaultCategories(
      db,
      languageCode,
      _selectedCurrencyCode,
    );

    // Інвалідуємо categoryProvider щоб HomeScreen підтягнув нові категорії
    ref.invalidate(categoryProvider);

    final storage = StorageService(ref.read(sharedPreferencesProvider));
    await storage.completeOnboarding();

    if (!mounted) return;

    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      ),
    );
  }

  // 👇 ОНОВЛЕНО: Використовуємо AuthController замість прямого сервісу
  Future<void> _signInWithGoogle() async {
    setState(() => _isSaving = true);
    try {
      final authNotifier = ref.read(authControllerProvider.notifier);

      // 👇 ФІКС 1: Отримуємо акаунт напряму і миттєво, без очікування стріму
      final account = await authNotifier.signIn();

      if (account != null) {
        if (!mounted) return;

        final wantToRestore = await _showRestorePromptDialog();

        if (wantToRestore) {
          setState(() => _isSaving = true);

          try {
            final driveService = ref.read(driveBackupServiceProvider);
            final db = ref.read(appDatabaseProvider);

            final restoreSuccess = await driveService.restoreDatabase(db);

            if (restoreSuccess) {
              // 👇 ФІКС 2: КРИТИЧНО! База була закрита сервісом. Її треба інвалідувати,
              // щоб HomeScreen створив абсолютно нове підключення до нового файлу!
              ref.invalidate(appDatabaseProvider);

              ref.invalidate(transactionProvider);
              ref.invalidate(categoryProvider);
              ref.invalidate(subscriptionProvider);
              ref.invalidate(statsProvider);

              _finishOnboarding();
            } else {
              if (mounted) {
                setState(() => _isSaving = false);
                AppSnackbar.error(context, 'restore_error'.tr());
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isSaving = false);
              AppSnackbar.error(context, 'restore_error'.tr());
            }
          }
        } else {
          _finishOnboarding();
        }
      } else {
        if (mounted) setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showRestorePromptDialog() {
    return AppDialog.confirm(
      context,
      title: 'account_connected'.tr(),
      message: 'restore_prompt_message'.tr(),
      icon: Icons.cloud_download_rounded,
      confirmText: 'restore'.tr(),
      cancelText: 'skip'.tr(),
      barrierDismissible: false,
    );
  }

  void _openLanguagePicker(AppColorsExtension colors) {
    FocusScope.of(context).unfocus();
    AppPickerSheet.show<String>(
      context: context,
      title: 'language_title'.tr(),
      enableSearch: true,
      selected: context.locale.languageCode,
      options: _supportedLanguages
          .map(
            (lang) => AppPickerOption(
              value: lang['code']!,
              label: lang['name']!,
              leading: AppPill(
                text: lang['short']!,
                color: colors.accent,
                width: 48,
              ),
              color: colors.accent,
            ),
          )
          .toList(),
      onSelected: (code) async {
        await context.setLocale(Locale(code));
        if (!mounted) return;
        final lang = _supportedLanguages.firstWhere(
          (l) => l['code'] == code,
        );
        setState(() => _languageCtrl.text = lang['name']!);
      },
    );
  }

  void _openCurrencyPicker(AppColorsExtension colors) {
    FocusScope.of(context).unfocus();
    AppPickerSheet.show<String>(
      context: context,
      title: 'base_currency_title'.tr(),
      enableSearch: true,
      selected: _selectedCurrencyCode,
      options: AppCurrency.ordered().map((c) {
        return AppPickerOption(
          value: c.code,
          label: 'currency_names.${c.code}'.tr(),
          leading: AppPill(text: '${c.code}  ${c.symbol}', color: colors.income),
          color: colors.income,
        );
      }).toList(),
      onSelected: (code) {
        setState(() {
          _selectedCurrencyCode = code;
          _currencyCtrl.text = 'currency_names.$code'.tr();
        });
      },
    );
  }

  Widget _buildSelectorField({
    required TextEditingController controller,
    required String label,
    required AppColorsExtension colors,
    required VoidCallback onTap,
    Widget? prefix,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        isEmpty: controller.text.isEmpty && prefix == null,
        decoration: InputDecoration(
          filled: false,
          labelText: label,
          labelStyle: TextStyle(color: colors.textSecondary, fontSize: 16),
          floatingLabelStyle: TextStyle(
            color: colors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          prefix: prefix,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Icon(Icons.keyboard_arrow_down, color: colors.textSecondary),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: colors.textSecondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.textMain, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            const Text(
              'Wj',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.transparent,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.text,
                    style: TextStyle(
                      color: colors.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final currentLocaleCode = context.locale.languageCode;

    final authState = ref.watch(authControllerProvider);
    final isGoogleLoading = authState.isLoading;
    final isAnyLoading = _isSaving || isGoogleLoading;

    final currentLang = _supportedLanguages.firstWhere(
      (lang) => lang['code'] == currentLocaleCode,
      orElse: () => _supportedLanguages.first,
    );

    final currencySymbol = AppCurrency.fromCode(_selectedCurrencyCode).symbol;

    return Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Логотип LiteBalance
                const Center(child: AppLogo(size: 200, halo: true)),
                const SizedBox(height: 32),

                // Привітання
                Text(
                  'onboarding_title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'onboarding_subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSelectorField(
                        controller: _languageCtrl,
                        label: 'language_title'.tr(),
                        colors: colors,
                        onTap: () => _openLanguagePicker(colors),
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.iconBg,
                            child: Text(
                              currentLang['short']!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.textMain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSelectorField(
                        controller: _currencyCtrl,
                        label: 'base_currency_title'.tr(),
                        colors: colors,
                        onTap: () => _openCurrencyPicker(colors),
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.iconBg,
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  currencySymbol.trim(),
                                  style: TextStyle(
                                    color: colors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Кнопка Google
                _buildGoogleButton(colors, isGoogleLoading, isAnyLoading),

                const SizedBox(height: 12),

                // Кнопка Продовжити локально
                _buildLocalStartButton(colors, isAnyLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(
    AppColorsExtension colors,
    bool isGoogleLoading,
    bool isAnyLoading,
  ) {
    final globalShape = Theme.of(
      context,
    ).elevatedButtonTheme.style?.shape?.resolve({});

    return ElevatedButton(
      onPressed: isAnyLoading ? null : _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.cardBg,
        foregroundColor: colors.textMain,
        minimumSize: const Size(double.infinity, 56),
        elevation: 2,
        shape:
            globalShape?.copyWith(
              side: BorderSide(
                color: colors.textSecondary.withValues(alpha: 0.2),
              ),
            ) ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: colors.textSecondary.withValues(alpha: 0.2),
              ),
            ),
      ),
      child: isGoogleLoading || _isSaving
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: colors.textMain,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/google.png', height: 24, width: 24),
                const SizedBox(width: 12),
                Text(
                  'sign_in_with_google'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLocalStartButton(AppColorsExtension colors, bool isAnyLoading) {
    return ElevatedButton(
      onPressed: isAnyLoading ? null : _finishOnboarding,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.textMain,
        foregroundColor: colors.cardBg,
        minimumSize: const Size(double.infinity, 56),
        elevation: 0,
      ),
      child: _isSaving && !ref.watch(authControllerProvider).isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: colors.cardBg,
                strokeWidth: 2,
              ),
            )
          : Text(
              'get_started'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}
