import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/csv_mapping_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';

// Заглушка для локалізації
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

// Заглушка для налаштувань
class TestSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'UAH',
    selectedCurrencies: const ['UAH', 'USD'],
    exchangeRates: const {'UAH': 1.0, 'USD': 40.0},
    historicalCache: const {},
    lastRatesUpdate: DateTime.now(),
  );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  // 👇 ВИПРАВЛЕНО: Явно вказуємо <dynamic> для кожного рядка, щоб не ламався метод orElse
  final testCsvData = <List<dynamic>>[
    <dynamic>['Date', 'Account', 'Category', 'Amount', 'Currency', 'Note'],
    <dynamic>[
      '12.05.2026',
      'Cash',
      'Supermarket',
      '150.50',
      'UAH',
      'Groceries',
    ],
    <dynamic>['Invalid', 'Cash', 'Food', 'BadAmount', 'UAH', ''],
    <dynamic>['13.05.2026', 'Bank', '', '100', 'USD', 'Empty target'],
    <dynamic>['01/06/2026', 'Bank', 'Salary', '"500,00"', 'USD', 'Bonus'],
  ];

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(() => TestSettingsNotifier()),
      ],
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
                scaffoldBackgroundColor: Colors.white,
                extensions: const [
                  AppColorsExtension(
                    bgGradientStart: Colors.white,
                    bgGradientEnd: Colors.white,
                    cardBg: Colors.white,
                    textMain: Colors.black,
                    textSecondary: Colors.grey,
                    income: Colors.green,
                    expense: Colors.red,
                    iconBg: Colors.grey,
                    accent: Colors.blue,
                  ),
                ],
              ),
              // 👇 ВИПРАВЛЕНО: Створюємо історію навігації, щоб з'явилася кнопка Назад
              initialRoute: '/csv',
              routes: {
                '/': (context) => const Scaffold(body: Text('Dummy Root')),
                '/csv': (context) => CsvMappingScreen(rawRows: testCsvData),
              },
            );
          },
        ),
      ),
    );
  }

  group('CsvMappingScreen Tests', () {
    testWidgets('1. Автовизначення колонок працює та пускає на Крок 2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('step_1_columns'), findsOneWidget);
      expect(find.text('next'), findsOneWidget);

      await tester.tap(find.text('next'));

      // Чекаємо завершення всіх Future (включаючи затримку 300мс)
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('step_2_categories'), findsOneWidget);
      expect(find.text('found_new_categories'), findsOneWidget);
      expect(find.text('Supermarket'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('2. Зміна типу категорії та успішний імпорт', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final incomeButtons = find.text('type_income');
      expect(incomeButtons, findsWidgets);
      await tester.tap(incomeButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('import_data_btn'));

      // Чекаємо, поки імпорт відпрацює і зробить Navigator.pop
      await tester.pumpAndSettle();

      // Екран має успішно закритися
      expect(find.byType(CsvMappingScreen), findsNothing);
    });

    testWidgets('3. BackButton працює: повертає з Кроку 2 на Крок 1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Йдемо на Крок 2
      await tester.tap(find.text('next'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.text('step_2_categories'), findsOneWidget);

      // 👇 ВИПРАВЛЕНО: Тепер кнопка точно є в дереві віджетів, і ми можемо її явно натиснути
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Перевіряємо, що PopScope перехопив клік і повернув нас на Крок 1
      expect(find.text('step_1_columns'), findsOneWidget);
    });
  });
}
