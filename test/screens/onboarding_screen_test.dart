import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/onboarding_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Заглушка для EasyLocalization
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Мокаємо SharedPreferences ПЕРЕД ініціалізацією EasyLocalization
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<Widget> createTestWidget() async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: const _MockAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: [
                ...context.localizationDelegates,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                extensions: const [
                  AppColorsExtension(
                    bgGradientStart: Colors.blue,
                    bgGradientEnd: Colors.blueAccent,
                    cardBg: Colors.white,
                    textMain: Colors.black,
                    textSecondary: Colors.grey,
                    income: Colors.green,
                    expense: Colors.red,
                    iconBg: Colors.grey,
                    accent: Colors.orange,
                  ),
                ],
              ),
              home: const OnboardingScreen(),
            );
          },
        ),
      ),
    );
  }

  group('OnboardingScreen UI Tests', () {
    testWidgets('Відображає головні елементи екрану', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('onboarding_title'), findsOneWidget);
      expect(find.text('language_title'), findsOneWidget);
      expect(find.text('base_currency_title'), findsOneWidget);
      expect(find.text('get_started'), findsOneWidget);
    });

    testWidgets('Відкриває BottomSheet для вибору мови', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      // Знаходимо GestureDetector, який огортає текст 'language_title'
      final languageField = find
          .ancestor(
            of: find.text('language_title'),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(languageField);
      await tester.pumpAndSettle();

      // Шукаємо 'English' САМЕ у вигляді елемента списку (ListTile),
      // щоб проігнорувати той 'English', який відображається у полі вводу на фоні
      expect(find.widgetWithText(ListTile, 'English'), findsOneWidget);
    });

    testWidgets('Відкриває BottomSheet для вибору валюти', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      // Знаходимо GestureDetector, який огортає текст 'base_currency_title'
      final currencyField = find
          .ancestor(
            of: find.text('base_currency_title'),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(currencyField);
      await tester.pumpAndSettle();

      // Шукаємо валюти САМЕ у вигляді елементів списку (ListTile)
      expect(find.widgetWithText(ListTile, 'USD'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'EUR'), findsOneWidget);
    });

    testWidgets('Кнопка Get Started показує лоадер', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('get_started'));
      // Використовуємо pump() замість pumpAndSettle(), бо анімація лоадера триває нескінченно
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
