import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'providers/all_providers.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';
import 'services/security_service.dart';
import 'widgets/common/sync_lifecycle_observer.dart';

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

  await initializeDateFormatting('uk_UA', null);
  const bool showPreview = false;

  // 3. Отримуємо статус онбордингу напряму з SharedPreferences
  final bool hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;
  final bool isPinSet = await SecurityService.isPinSet();

  runApp(
    // Використовуємо UncontrolledProviderScope, щоб передати вже створений контейнер
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('uk'), Locale('en'), Locale('de')],
        path: 'assets/translations',
        fallbackLocale: const Locale('uk'),
        child: DevicePreview(
          enabled: !kReleaseMode && showPreview,
          builder: (context) => MyApp(
            showOnboarding: !hasCompletedOnboarding,
            requirePin: isPinSet,
          ),
        ),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool showOnboarding;
  final bool requirePin;

  const MyApp({
    super.key,
    required this.showOnboarding,
    this.requirePin = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Реактивно стежимо за темою через Riverpod
    final themeId = ref.watch(themeProvider);
    final currentTheme = AppTheme.getTheme(themeId);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: currentTheme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    // 👇 ТУТ МИ ПРИБРАЛИ обгортку ззовні
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CoinFlow',
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: currentTheme,

      // 👇 ТУТ МИ ЇЇ ДОДАЛИ: builder обгортає всі екрани, маючи доступ до ScaffoldMessenger
      builder: (context, child) {
        final Widget currentChild = DevicePreview.appBuilder(context, child);
        final mediaQueryData = MediaQuery.of(context);
        final double baseScale = mediaQueryData.textScaler.scale(10) / 10;
        final double safeScale = baseScale.clamp(1.0, 1.15);

        return SyncLifecycleObserver(
          child: MediaQuery(
            data: mediaQueryData.copyWith(
              textScaler: TextScaler.linear(safeScale),
            ),
            child: currentChild,
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
      home: showOnboarding
          ? const OnboardingScreen()
          : (requirePin ? const LockScreen() : const HomeScreen()),
    );
  }
}
