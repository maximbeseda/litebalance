import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/profile_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Заглушка для локалізації
class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return <String, dynamic>{};
  }
}

// --- МОК-НОТИФІКАТОРИ ---

class TestCategoryNotifier extends CategoryNotifier {
  final CategoryState mockState;
  TestCategoryNotifier(this.mockState);
  @override
  CategoryState build() => mockState;
}

class TestTransactionNotifier extends TransactionNotifier {
  final TransactionState mockState;
  TestTransactionNotifier(this.mockState);
  @override
  Future<TransactionState> build() async => mockState;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // 1. Мокаємо SharedPreferences та PackageInfo
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Coin Flow',
      packageName: 'com.example.coinflow',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'buildSignature',
    );

    // 2. Мокаємо нативні канали безпеки (Secure Storage та Biometrics),
    // щоб SecurityService.isPinSet() не крашив onTap.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/local_auth'),
          (MethodCall methodCall) async => false,
        );

    await EasyLocalization.ensureInitialized();
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  // --- ДАНІ БАЗИ ---
  const dummyAccount = Category(
    id: 'acc_1',
    type: CategoryType.account,
    name: 'Wallet',
    icon: 0xe041,
    bgColor: 0xFF2196F3,
    iconColor: 0xFFFFFFFF,
    amount: 1000,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
    deletedAt: null,
  );

  final dummyTx = Transaction(
    id: 'tx_1',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Test',
    titleLower: 'test',
    date: DateTime(2026, 4, 27),
    amount: 100,
    currency: 'UAH',
    targetAmount: null,
    targetCurrency: null,
    baseAmount: 100,
    baseCurrency: 'UAH',
    deletedAt: null,
  );

  final defaultCategoryState = CategoryState(
    incomes: const [],
    accounts: const [dummyAccount],
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  final defaultTransactionState = TransactionState(
    history: [dummyTx],
    deletedHistory: const [],
    selectedMonth: DateTime(2026, 4, 1),
    isMigrating: false,
  );

  // --- ВІДЖЕТ ДЛЯ ТЕСТУВАННЯ ---
  Future<Widget> createTestWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        packageInfoProvider.overrideWithValue(packageInfo),
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
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
              home: const ProfileScreen(),
            );
          },
        ),
      ),
    );
  }

  // --- ТЕСТИ ---
  group('ProfileScreen UI Tests', () {
    testWidgets('Відображає головні елементи профілю', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('profile'), findsOneWidget);
      expect(find.text('interface_theme'), findsOneWidget);
      expect(find.text('language'), findsOneWidget);
      expect(find.text('base_currency'), findsOneWidget);

      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('pin_code'), findsOneWidget);

      expect(find.text('clear_all_data'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    });

    testWidgets('Відкриває діалог підтвердження при очищенні даних', (
      tester,
    ) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      // Явно знаходимо всю плитку (ListTile), а не просто текст
      final clearBtn = find.widgetWithText(ListTile, 'clear_all_data');
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);

      // Використовуємо pump() декілька разів, щоб дочекатись завершення
      // асинхронних операцій SecurityService перед анімацією діалогу
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('clear_data_title'), findsOneWidget);
      expect(find.text('clear_data_message'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
      expect(find.text('delete'), findsOneWidget);
    });

    testWidgets('Закриває діалог при натисканні Cancel', (tester) async {
      setLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(await createTestWidget());
      await tester.pumpAndSettle();

      final clearBtn = find.widgetWithText(ListTile, 'clear_all_data');
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(find.text('clear_data_title'), findsNothing);
    });
  });
}
