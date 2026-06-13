import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'providers/all_providers.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'services/security_service.dart';
import 'utils/currency_formatter.dart';
import 'widgets/common/sync_lifecycle_observer.dart' show SyncLifecycleObserver;
import 'widgets/common/app_lock_gate.dart'
    show AppLockGate, kAutoLockTimeoutMs, kLockBgTimeKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 1. Ініціалізуємо SharedPreferences ДО запуску UI
  final prefs = await SharedPreferences.getInstance();

  // Отримуємо інформацію про версію
  final packageInfo = await PackageInfo.fromPlatform();

  // 2. Створюємо контейнер Riverpod і ПЕРЕДАЄМО туди prefs
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      packageInfoProvider.overrideWithValue(packageInfo),
    ],
  );

  // Ініціалізуємо дані формату дат для ВСІХ локалей, щоб назви місяців/днів
  // відображалися мовою інтерфейсу (а не лише українською).
  await initializeDateFormatting();

  // 3. Отримуємо статус онбордингу напряму з SharedPreferences
  final bool hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;
  final bool isPinSet = await SecurityService.isPinSet();
  // Кеш для синхронної перевірки в SyncLifecycleObserver (без await)
  await prefs.setBool('pin_set_cache', isPinSet);

  // Показуємо LockScreen тільки якщо PIN встановлений І минув таймаут
  bool requirePin = false;
  if (isPinSet) {
    final bgTime = prefs.getInt(kLockBgTimeKey);
    if (bgTime == null) {
      requirePin = true;
    } else {
      final elapsed = DateTime.now().millisecondsSinceEpoch - bgTime;
      requirePin = elapsed >= kAutoLockTimeoutMs;
    }
  }

  runApp(
    // Використовуємо UncontrolledProviderScope, щоб передати вже створений контейнер
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [
          Locale('uk'),
          Locale('en'),
          Locale('de'),
          Locale('pl'),
          Locale('es'),
          Locale('fr'),
          Locale('it'),
          Locale('pt'),
          Locale('nl'),
          Locale('tr'),
          Locale('cs'),
          Locale('ro'),
          Locale('hu'),
          Locale('sk'),
          Locale('el'),
          Locale('bg'),
          Locale('sv'),
          Locale('da'),
          Locale('fi'),
          Locale('hr'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('uk'),
        child: MyApp(
          showOnboarding: !hasCompletedOnboarding,
          requirePin: requirePin,
        ),
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final bool showOnboarding;
  final bool requirePin;

  const MyApp({
    super.key,
    required this.showOnboarding,
    this.requirePin = false,
  });

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(themeProvider);
    final currentTheme = AppTheme.getTheme(themeId);

    // Тримаємо форматування чисел/дат і скорочення мільйонів у синхроні з мовою.
    Intl.defaultLocale = context.locale.toString();
    CurrencyFormatter.millionSuffix = 'million_suffix'.tr();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: currentTheme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      title: 'LiteBalance',
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: currentTheme,

      builder: (context, child) {
        final Widget currentChild = child ?? const SizedBox.shrink();
        final mediaQueryData = MediaQuery.of(context);
        final double baseScale = mediaQueryData.textScaler.scale(10) / 10;
        final double safeScale = baseScale.clamp(1.0, 1.15);

        return AppLockGate(
          initiallyLocked: widget.requirePin,
          child: SyncLifecycleObserver(
            child: MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.linear(safeScale),
              ),
              child: currentChild,
            ),
          ),
        );
      },
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      home: widget.showOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
