import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/native.dart';

import 'package:coin_flow/main.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/home_screen.dart';
import 'package:coin_flow/screens/onboarding_screen.dart';
import 'package:coin_flow/screens/lock_screen.dart';

// 👇 1. Мок для локалізації
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{};
  }
}

// Заглушка для налаштувань
class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH'],
    exchangeRates: const {},
    historicalCache: const {},
    lastRatesUpdate: DateTime.now(),
  );
}

void main() {
  late SharedPreferences sharedPrefs;
  late PackageInfo packageInfo;
  late AppDatabase db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    PackageInfo.setMockInitialValues(
      appName: 'LiteBalance',
      packageName: 'com.example.coinflow',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'buildSignature',
    );
    packageInfo = await PackageInfo.fromPlatform();
  });

  setUp(() async {
    sharedPrefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MyApp Navigation Tests', () {
    Widget createTestableMyApp({
      required bool showOnboarding,
      bool requirePin = false,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          packageInfoProvider.overrideWithValue(packageInfo),
          appDatabaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(() => TestSettingsNotifier()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('uk'), Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('uk'),
          assetLoader: const _MockAssetLoader(),
          child: Builder(
            builder: (context) {
              return MyApp(
                showOnboarding: showOnboarding,
                requirePin: requirePin,
              );
            },
          ),
        ),
      );
    }

    testWidgets('1. Показує OnboardingScreen, якщо showOnboarding: true', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0; // Гарантуємо великий логічний розмір
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableMyApp(showOnboarding: true));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('2. Показує LockScreen, якщо PIN встановлено', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio =
          1.0; // 👇 ФІКС: Це прибере помилку Overflow
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableMyApp(showOnboarding: false, requirePin: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LockScreen), findsOneWidget);
    });

    testWidgets('3. Показує HomeScreen, якщо онбординг пройдено', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableMyApp(showOnboarding: false, requirePin: false),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
