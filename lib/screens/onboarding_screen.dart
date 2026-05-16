import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/all_providers.dart';
import '../services/storage_service.dart';
import '../models/app_currency.dart';
import '../theme/app_colors_extension.dart';
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

  final List<Map<String, String>> _supportedLanguages = [
    {'code': 'uk', 'name': 'Українська', 'short': 'UK'},
    {'code': 'en', 'name': 'English', 'short': 'EN'},
    {'code': 'de', 'name': 'Deutsch', 'short': 'DE'},
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
    _currencyCtrl.text = initialCurrency;
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

    final settingsNotifier = ref.read(settingsProvider.notifier);
    await settingsNotifier.setBaseCurrency(_selectedCurrencyCode);

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
      // Викликаємо правильний провайдер, який збереже все в кеш
      final authNotifier = ref.read(authControllerProvider.notifier);
      await authNotifier.signIn();

      // Отримуємо результат з його стану
      final account = ref.read(authControllerProvider).value;

      if (account != null) {
        if (!mounted) return;

        final wantToRestore = await _showRestorePromptDialog();

        if (wantToRestore) {
          setState(() => _isSaving = true);

          try {
            final driveService = ref.read(driveBackupServiceProvider);
            final db = ref.read(appDatabaseProvider); // Отримуємо базу даних

            // ✅ Викликаємо метод з параметром db
            final restoreSuccess = await driveService.restoreDatabase(db);

            if (restoreSuccess) {
              // Очищаємо кеш провайдерів
              ref.invalidate(transactionProvider);
              ref.invalidate(categoryProvider);
              ref.invalidate(subscriptionProvider);
              ref.invalidate(statsProvider);

              // Йдемо на Головний екран
              _finishOnboarding();
            } else {
              // Якщо метод повернув false (бекапу немає)
              if (mounted) {
                setState(() => _isSaving = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('restore_error'.tr())));
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('restore_error'.tr())));
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

  Future<bool> _showRestorePromptDialog() async {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
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
                      color: colors.income.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_download_rounded,
                      color: colors.income,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'account_connected'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'restore_prompt_message'.tr(),
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
                            'skip'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.income,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'restore'.tr(),
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
  }

  void _openLanguagePicker(AppColorsExtension colors) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'language_title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = _supportedLanguages[index];
                    final bool isSelected =
                        context.locale.languageCode == lang['code'];

                    return ListTile(
                      onTap: () async {
                        await context.setLocale(Locale(lang['code']!));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _languageCtrl.text = lang['name']!;
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? colors.textMain
                            : colors.iconBg,
                        child: Text(
                          lang['short']!,
                          style: TextStyle(
                            color: isSelected ? colors.cardBg : colors.textMain,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        lang['name']!,
                        style: TextStyle(
                          color: colors.textMain,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colors.textMain)
                          : null,
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

  void _openCurrencyPicker(AppColorsExtension colors) {
    FocusScope.of(context).unfocus();
    final List<String> availableCurrencies = AppCurrency.supportedCurrencies
        .map((c) => c.code)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'base_currency_title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableCurrencies.length,
                  itemBuilder: (context, index) {
                    final code = availableCurrencies[index];
                    final curr = AppCurrency.fromCode(code);
                    final bool isSelected = _selectedCurrencyCode == code;

                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCurrencyCode = code;
                          _currencyCtrl.text = code;
                        });
                        Navigator.pop(ctx);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? colors.textMain
                            : colors.iconBg,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              curr.symbol.trim(),
                              style: TextStyle(
                                color: isSelected
                                    ? colors.cardBg
                                    : colors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        curr.code,
                        style: TextStyle(
                          color: colors.textMain,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colors.textMain)
                          : null,
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

                // Логотип
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: colors.textMain,
                  ),
                ),
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
