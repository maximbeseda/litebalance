import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Плагіни для імітації мережі
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:coin_flow/widgets/common/sync_lifecycle_observer.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/drive_backup_service.dart';
import 'package:coin_flow/services/google_auth_service.dart';

// --- МОКИ СЕРВІСІВ ---
class MockDriveBackupService extends Mock implements DriveBackupService {}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockConnectivityPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {}

class AppDatabaseFake extends Fake implements AppDatabase {}

// ============================================================================
// Фейкові провайдери
// ============================================================================
class TestSettingsNotifier extends SettingsNotifier {
  // 👇 ФІКС: Додали змінну, щоб прокидати налаштування з тесту!
  final bool syncOnlyViaWifi;

  TestSettingsNotifier({this.syncOnlyViaWifi = false});

  @override
  SettingsState build() => SettingsState(
    baseCurrency: 'USD',
    selectedCurrencies: const ['USD'],
    exchangeRates: const {'USD': 1.0},
    historicalCache: const {},
    syncOnlyViaWifi: syncOnlyViaWifi, // Використовуємо передане значення
  );
  @override
  Future<void> updateCloudBackupTime() async {}
}

class TestTransactionNotifier extends TransactionNotifier {
  @override
  Future<TransactionState> build() async => TransactionState(
    history: const [],
    deletedHistory: const [],
    selectedMonth: DateTime.now(),
    isMigrating: false,
  );
  @override
  Future<void> loadHistory({bool showLoading = true}) async {}
}

class TestCategoryNotifier extends CategoryNotifier {
  @override
  CategoryState build() => CategoryState(
    incomes: const [],
    accounts: const [],
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );
  @override
  Future<void> loadCategories({bool showLoading = true}) async {}
}

class TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => SubscriptionState(
    subscriptions: const [],
    dueSubscriptions: const [],
    deletedSubscriptions: const [],
    ignoredSubIds: const {},
  );
  @override
  Future<void> loadSubscriptions() async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(AppDatabaseFake());
  });

  late MockDriveBackupService mockDriveService;
  late MockGoogleAuthService mockAuthService;
  late MockSharedPreferences mockPrefs;
  late MockGoogleSignInAccount mockAccount;
  late MockAppDatabase mockDb;
  late MockConnectivityPlatform mockConnectivity;
  late StreamController<GoogleSignInAccount?> authStreamController;

  setUp(() {
    mockDriveService = MockDriveBackupService();
    mockAuthService = MockGoogleAuthService();
    mockPrefs = MockSharedPreferences();
    mockAccount = MockGoogleSignInAccount();
    mockDb = MockAppDatabase();
    mockConnectivity = MockConnectivityPlatform();
    authStreamController = StreamController<GoogleSignInAccount?>.broadcast();

    // Підміняємо реальний плагін мережі на наш фейковий
    ConnectivityPlatform.instance = mockConnectivity;

    // Базові налаштування (за замовчуванням база брудна, юзер увійшов і пройшов онбординг)
    when(() => mockPrefs.getBool(any())).thenReturn(true);
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.getString(any())).thenReturn(null);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

    // Імітуємо авторизованого юзера
    when(() => mockAuthService.currentUser).thenReturn(mockAccount);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => authStreamController.stream);

    // Дані акаунта
    when(() => mockAccount.displayName).thenReturn('Максим');
    when(() => mockAccount.email).thenReturn('max@test.com');
    when(() => mockAccount.photoUrl).thenReturn('https://photo.url');

    // Імітуємо успішний бекап
    when(
      () => mockDriveService.performSmartSync(
        any(),
        any(),
        allowInteractive: any(named: 'allowInteractive'),
      ),
    ).thenAnswer((_) async => SyncStatus.backedUp);
  });

  tearDown(() {
    authStreamController.close();
  });

  // Хелпер для запуску віджета (додали параметр syncOnlyViaWifi)
  Future<ProviderContainer> pumpObserver(
    WidgetTester tester, {
    bool syncOnlyViaWifi = false,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    final container = ProviderContainer(
      overrides: [
        driveBackupServiceProvider.overrideWithValue(mockDriveService),
        googleAuthServiceProvider.overrideWithValue(mockAuthService),
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        appDatabaseProvider.overrideWithValue(mockDb),
        // Передаємо параметр безпосередньо у фейковий Settings-провайдер
        settingsProvider.overrideWith(
          () => TestSettingsNotifier(syncOnlyViaWifi: syncOnlyViaWifi),
        ),
        transactionProvider.overrideWith(() => TestTransactionNotifier()),
        categoryProvider.overrideWith(() => TestCategoryNotifier()),
        subscriptionProvider.overrideWith(() => TestSubscriptionNotifier()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SyncLifecycleObserver(
            child: Scaffold(body: Text('Test Child')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    return container;
  }

  group('SyncLifecycleObserver Tests -', () {
    testWidgets('НЕ робить бекап, якщо база не брудна', (tester) async {
      when(() => mockPrefs.getBool('is_db_dirty_persistent')).thenReturn(false);

      await pumpObserver(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      verifyNever(
        () => mockDriveService.performSmartSync(
          any(),
          any(),
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });

    testWidgets('НЕ робить бекап, якщо користувач не увійшов у Google', (
      tester,
    ) async {
      when(
        () => mockPrefs.getBool('has_logged_in_with_google'),
      ).thenReturn(false);
      when(() => mockAuthService.currentUser).thenReturn(null);

      await pumpObserver(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      verifyNever(
        () => mockDriveService.performSmartSync(
          any(),
          any(),
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });

    testWidgets('НЕ робить бекап, якщо онбординг не завершено', (tester) async {
      when(
        () => mockPrefs.getBool('has_completed_onboarding'),
      ).thenReturn(false);

      await pumpObserver(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      verifyNever(
        () => mockDriveService.performSmartSync(
          any(),
          any(),
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });

    testWidgets('Робить бекап при згортанні (paused), якщо є Wi-Fi', (
      tester,
    ) async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);

      final container = await pumpObserver(tester);

      authStreamController.add(mockAccount);
      await tester.pump();
      await container.read(authControllerProvider.future);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      verify(
        () => mockDriveService.performSmartSync(
          mockDb,
          true,
          allowInteractive: false,
        ),
      ).called(1);
    });

    testWidgets('НЕ робить бекап, якщо увімкнено "Лише Wi-Fi", а ми на 4G', (
      tester,
    ) async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.mobile]);

      // 👇 ФІКС: Тепер ми передаємо syncOnlyViaWifi = true напряму в хелпер!
      await pumpObserver(tester, syncOnlyViaWifi: true);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();

      verifyNever(
        () => mockDriveService.performSmartSync(
          any(),
          any(),
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });

    testWidgets('Робить бекап при розгортанні (resumed) як страховка', (
      tester,
    ) async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);

      final container = await pumpObserver(tester);

      authStreamController.add(mockAccount);
      await tester.pump();
      await container.read(authControllerProvider.future);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      verify(
        () => mockDriveService.performSmartSync(
          mockDb,
          true,
          allowInteractive: false,
        ),
      ).called(1);
    });
  });
}
