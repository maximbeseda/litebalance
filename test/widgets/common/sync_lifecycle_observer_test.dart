import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Плагіни для імітації мережі
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// 👇 Заміни на свої реальні імпорти
import 'package:coin_flow/widgets/common/sync_lifecycle_observer.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/drive_backup_service.dart';
import 'package:coin_flow/services/google_auth_service.dart';

// --- МОКИ ---
class MockDriveBackupService extends Mock implements DriveBackupService {}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockAppDatabase extends Mock implements AppDatabase {}

// Спеціальний мок для імітації Wi-Fi / Мобільного інтернету
class MockConnectivityPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {}

class AppDatabaseFake extends Fake implements AppDatabase {}

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

  setUp(() {
    mockDriveService = MockDriveBackupService();
    mockAuthService = MockGoogleAuthService();
    mockPrefs = MockSharedPreferences();
    mockAccount = MockGoogleSignInAccount();
    mockDb = MockAppDatabase();
    mockConnectivity = MockConnectivityPlatform();

    // Підміняємо реальний плагін мережі на наш фейковий
    ConnectivityPlatform.instance = mockConnectivity;

    // Базові налаштування
    when(() => mockPrefs.getBool(any())).thenReturn(true); // Ніби база "брудна"
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.getString(any())).thenReturn(null); // Для settings
    when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);

    // Імітуємо авторизованого юзера
    when(() => mockAuthService.currentUser).thenReturn(mockAccount);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => Stream.value(mockAccount));

    // Імітуємо успішний бекап
    when(
      () => mockDriveService.backupDatabase(any()),
    ).thenAnswer((_) async => true);
  });

  // Хелпер для запуску віджета
  Future<ProviderContainer> pumpObserver(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        driveBackupServiceProvider.overrideWithValue(mockDriveService),
        googleAuthServiceProvider.overrideWithValue(mockAuthService),
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        appDatabaseProvider.overrideWithValue(mockDb),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncLifecycleObserver(
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
      // База чиста
      when(() => mockPrefs.getBool('is_db_dirty_persistent')).thenReturn(false);

      await pumpObserver(tester);

      // Симулюємо згортання додатку
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Перевіряємо, що запит до Google Drive НЕ викликався
      verifyNever(() => mockDriveService.backupDatabase(any()));
    });

    testWidgets('НЕ робить бекап, якщо користувач не увійшов у Google', (
      tester,
    ) async {
      // Юзер розлогінений
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => Stream.value(null));

      await pumpObserver(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      verifyNever(() => mockDriveService.backupDatabase(any()));
    });

    testWidgets('Робить бекап при згортанні (paused), якщо є Wi-Fi', (
      tester,
    ) async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);

      final container = await pumpObserver(tester);

      // 1. КРИТИЧНО: Чекаємо, поки AuthController ініціалізується,
      // щоб .value не був null під час виклику бекапу
      await container.read(authControllerProvider.future);

      // 2. Використовуємо runAsync для виконання реальних асинхронних викликів всередині тесту
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

        // Даємо час асинхронним методам всередині _attemptAutoBackup відпрацювати
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpAndSettle();

      // Тепер verify точно знайде виклик
      verify(() => mockDriveService.backupDatabase(mockDb)).called(1);
      verify(
        () => mockPrefs.setBool('is_db_dirty_persistent', false),
      ).called(1);
    });

    testWidgets('НЕ робить бекап, якщо увімкнено "Лише Wi-Fi", а ми на 4G', (
      tester,
    ) async {
      // Імітуємо мобільний інтернет
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.mobile]);

      // Імітуємо, що в налаштуваннях увімкнено "Лише Wi-Fi"
      when(() => mockPrefs.getBool('sync_only_wifi')).thenReturn(true);

      await pumpObserver(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();

      // Бекап не повинен відбутися
      verifyNever(() => mockDriveService.backupDatabase(any()));
    });

    testWidgets('Робить бекап при розгортанні (resumed) як страховка', (
      tester,
    ) async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);

      final container = await pumpObserver(tester);

      // Чекаємо ініціалізацію акаунта
      await container.read(authControllerProvider.future);

      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpAndSettle();

      verify(() => mockDriveService.backupDatabase(mockDb)).called(1);
    });
  });
}
