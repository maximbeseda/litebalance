import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:coin_flow/widgets/common/settings_drawer.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/google_auth_service.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';

// Імпортуємо всі екрани для навігації
import 'package:coin_flow/screens/profile_screen.dart';
import 'package:coin_flow/screens/stats/stats_screen.dart';
import 'package:coin_flow/screens/currencies_screen.dart';
import 'package:coin_flow/screens/import_export_screen.dart';
import 'package:coin_flow/screens/backup_management_screen.dart';
import 'package:coin_flow/screens/subscriptions_screen.dart';
import 'package:coin_flow/screens/trash_screen.dart';

// ==========================================
// МОКИ КЛАСІВ ТА СТАНІВ
// ==========================================
class MockCategory extends Mock implements Category {}

class MockTransaction extends Mock implements Transaction {}

class MockSubscription extends Mock implements Subscription {}

class MockCategoryState extends Mock implements CategoryState {}

class MockTransactionState extends Mock implements TransactionState {}

class MockSubscriptionState extends Mock implements SubscriptionState {}

class MockSettingsState extends Mock implements SettingsState {}

class MockSyncState extends Mock implements SyncState {}

class MockSyncLogic extends Mock {
  Future<void> syncNow({bool isAuto = false});
}

class MockGoogleAuthService extends Mock implements GoogleAuthService {
  @override
  Stream<GoogleSignInAccount?> get authStateChanges => const Stream.empty();
}

class FakeAppColorsExtension extends Fake implements AppColorsExtension {
  @override
  Object get type => AppColorsExtension;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      return Colors.black;
    }
    if (invocation.memberName == #copyWith || invocation.memberName == #lerp) {
      return this;
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'settings': 'Settings',
    'profile': 'Profile',
    'statistics': 'Statistics',
    'exchange_rates': 'Exchange Rates',
    'data_management': 'Data Management',
    'backup_title': 'Backups',
    'regular_payments': 'Regular Payments',
    'trash': 'Trash',
    'never': 'Never',
    'last_sync': 'Last Sync',
    'sync_now': 'Sync Now',
  };
}

// ==========================================
// ФЕЙКОВІ ПРОВАЙДЕРИ (Riverpod 3.0)
// ==========================================
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

class TestSubscriptionNotifier extends SubscriptionNotifier {
  final SubscriptionState mockState;
  TestSubscriptionNotifier(this.mockState);
  @override
  Future<SubscriptionState> build() async => mockState;
}

class TestSettingsNotifier extends SettingsNotifier {
  final SettingsState mockState;
  TestSettingsNotifier(this.mockState);
  @override
  SettingsState build() => mockState;
}

class TestSyncController extends SyncController {
  final SyncState mockState;
  final MockSyncLogic logic;
  TestSyncController(this.mockState, this.logic);

  @override
  SyncState build() => mockState;

  @override
  Future<void> syncNow({bool isAuto = false}) => logic.syncNow(isAuto: isAuto);
}

void main() {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildDrawerApp(
    WidgetTester tester, {
    int deletedCatsCount = 0,
    int deletedTxsCount = 0,
    int deletedSubsCount = 0,
    bool hasPendingSubs = false,
    DateTime? lastSyncDate,
    bool isSyncing = false,
    bool isSyncError = false,
    MockSyncLogic? syncLogic,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final catState = MockCategoryState();
    when(
      () => catState.deletedCategories,
    ).thenReturn(List.filled(deletedCatsCount, MockCategory()));
    when(() => catState.incomes).thenReturn([]);
    when(() => catState.expenses).thenReturn([]);
    when(() => catState.accounts).thenReturn([]);
    when(() => catState.allCategoriesList).thenReturn([]);

    final txState = MockTransactionState();
    when(
      () => txState.deletedHistory,
    ).thenReturn(List.filled(deletedTxsCount, MockTransaction()));
    when(() => txState.history).thenReturn([]);
    when(() => txState.selectedMonth).thenReturn(DateTime.now());
    // 👇 ФІКС: Надаємо значення за замовчуванням для екрану статистики
    when(() => txState.isMigrating).thenReturn(false);

    final subState = MockSubscriptionState();
    when(
      () => subState.deletedSubscriptions,
    ).thenReturn(List.filled(deletedSubsCount, MockSubscription()));
    when(() => subState.hasPendingPayments).thenReturn(hasPendingSubs);
    when(() => subState.subscriptions).thenReturn([]);

    final settingsState = MockSettingsState();
    when(() => settingsState.lastCloudBackup).thenReturn(lastSyncDate);
    when(() => settingsState.baseCurrency).thenReturn('UAH');
    when(() => settingsState.selectedCurrencies).thenReturn(['UAH', 'USD']);
    when(() => settingsState.exchangeRates).thenReturn({});
    when(() => settingsState.syncOnlyViaWifi).thenReturn(false);

    final syncState = MockSyncState();
    when(() => syncState.isSyncing).thenReturn(isSyncing);
    when(() => syncState.hasError).thenReturn(isSyncError);

    final mockAuthService = MockGoogleAuthService();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryProvider.overrideWith(() => TestCategoryNotifier(catState)),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(txState),
        ),
        subscriptionProvider.overrideWith(
          () => TestSubscriptionNotifier(subState),
        ),
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(settingsState),
        ),
        syncControllerProvider.overrideWith(
          () => TestSyncController(syncState, syncLogic ?? MockSyncLogic()),
        ),
        googleAuthServiceProvider.overrideWithValue(mockAuthService),
        packageInfoProvider.overrideWithValue(
          PackageInfo(
            appName: 'Test',
            packageName: 'test',
            version: '1',
            buildNumber: '1',
          ),
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
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData(extensions: [FakeAppColorsExtension()]),
              home: Scaffold(
                key: scaffoldKey,
                body: const Center(child: Text('Home Screen')),
                drawer: const SettingsDrawer(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> openDrawerAndTap(WidgetTester tester, IconData icon) async {
    await tester.pumpAndSettle();
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(icon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('SettingsDrawer Full Coverage Tests -', () {
    testWidgets('1. Відкриває Drawer та рендерить всі пункти меню', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));

      await tester.pumpAndSettle();
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
      expect(find.byIcon(Icons.currency_exchange), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.save_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.autorenew), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('2. Навігація: Перехід на ProfileScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));
      await openDrawerAndTap(tester, Icons.person_outline);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('3. Навігація: Перехід на StatsScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));
      await openDrawerAndTap(tester, Icons.pie_chart_outline);
      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('4. Навігація: Перехід на CurrenciesScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));
      await openDrawerAndTap(tester, Icons.currency_exchange);
      expect(find.byType(CurrenciesScreen), findsOneWidget);
    });

    testWidgets('5. Навігація: Перехід на ImportExportScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));
      await openDrawerAndTap(tester, Icons.import_export);
      expect(find.byType(ImportExportScreen), findsOneWidget);
    });

    testWidgets('6. Навігація: Перехід на BackupManagementScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester));
      await openDrawerAndTap(tester, Icons.save_alt_rounded);
      expect(find.byType(BackupManagementScreen), findsOneWidget);
    });

    testWidgets(
      '7. Підписки: Показує червону крапку (hasPending) і переходить на SubscriptionsScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await buildDrawerApp(tester, hasPendingSubs: true),
        );

        await tester.pumpAndSettle();
        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        final dotFinder = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(dotFinder, findsWidgets);

        await tester.tap(find.byIcon(Icons.autorenew));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SubscriptionsScreen), findsOneWidget);
      },
    );

    testWidgets(
      '8. Кошик: Рахує суму видалених елементів і переходить на TrashScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await buildDrawerApp(
            tester,
            deletedCatsCount: 1,
            deletedTxsCount: 2,
            deletedSubsCount: 1,
          ),
        );

        await tester.pumpAndSettle();
        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        expect(find.text('4'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TrashScreen), findsOneWidget);
      },
    );

    testWidgets(
      '9. Синхронізація: Показує відформатовану дату останньої синхронізації',
      (WidgetTester tester) async {
        final syncDate = DateTime(2026, 4, 1, 15, 30);
        await tester.pumpWidget(
          await buildDrawerApp(tester, lastSyncDate: syncDate),
        );

        await tester.pumpAndSettle();
        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        expect(find.text('01.04.2026 15:30'), findsOneWidget);
        expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      },
    );

    testWidgets('10. Синхронізація: Показує лоадер під час isSyncing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp(tester, isSyncing: true));

      await tester.pumpAndSettle();
      scaffoldKey.currentState!.openDrawer();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      '11. Синхронізація: Показує іконку помилки під час isSyncError',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await buildDrawerApp(tester, isSyncError: true),
        );

        await tester.pumpAndSettle();
        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      },
    );

    testWidgets('12. Синхронізація: Натискання на кнопку викликає syncNow()', (
      WidgetTester tester,
    ) async {
      final mockLogic = MockSyncLogic();
      when(
        () => mockLogic.syncNow(isAuto: any(named: 'isAuto')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        await buildDrawerApp(tester, syncLogic: mockLogic),
      );

      await tester.pumpAndSettle();
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sync Now'));
      await tester.pump();

      verify(() => mockLogic.syncNow()).called(1);
    });
  });
}
