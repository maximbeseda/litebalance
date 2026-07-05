import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:litebalance/providers/all_providers.dart';
import 'package:litebalance/services/google_auth_service.dart';

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockSharedPreferences mockPrefs;
  late MockGoogleSignInAccount mockAccount;
  late StreamController<GoogleSignInAccount?> streamController;

  const String authFlagKey = 'has_logged_in_with_google';

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockPrefs = MockSharedPreferences();
    mockAccount = MockGoogleSignInAccount();

    // 👇 Створюємо живий контролер потоку для кожного тесту
    streamController = StreamController<GoogleSignInAccount?>.broadcast();

    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => streamController.stream);

    // Базові налаштування кешу
    when(() => mockPrefs.getBool(any())).thenReturn(false);
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
  });

  tearDown(() {
    streamController.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        googleAuthServiceProvider.overrideWithValue(mockAuthService),
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthController Tests -', () {
    test(
      'Слухач authStateChanges правильно оновлює стан та SharedPreferences',
      () async {
        when(() => mockAccount.displayName).thenReturn('Максим');
        when(() => mockAccount.email).thenReturn('max@test.com');
        when(() => mockAccount.photoUrl).thenReturn('https://photo.url');
        when(() => mockAuthService.currentUser).thenReturn(null);

        final container = createContainer();
        await container.read(authControllerProvider.future);

        // 1. Імітуємо подію логіну (Google прислав акаунт у потік)
        streamController.add(mockAccount);
        // Даємо час асинхронному мікротаску відпрацювати
        await Future.delayed(Duration.zero);

        // Перевіряємо, чи стан оновився і чи записались дані
        expect(container.read(authControllerProvider).value, mockAccount);
        verify(() => mockPrefs.setBool(authFlagKey, true)).called(1);
        verify(
          () => mockPrefs.setString('google_user_name', 'Максим'),
        ).called(1);
        verify(
          () => mockPrefs.setString('google_user_email', 'max@test.com'),
        ).called(1);
        verify(
          () => mockPrefs.setString('google_user_photo', 'https://photo.url'),
        ).called(1);

        // 2. Імітуємо подію розлогіну (Google прислав null у потік)
        streamController.add(null);
        await Future.delayed(Duration.zero);

        // Перевіряємо, чи стан скинувся і чи очистився кеш
        expect(container.read(authControllerProvider).value, isNull);
        verify(() => mockPrefs.setBool(authFlagKey, false)).called(1);
        verify(() => mockPrefs.remove('google_user_name')).called(1);
        verify(() => mockPrefs.remove('google_user_email')).called(1);
        verify(() => mockPrefs.remove('google_user_photo')).called(1);
      },
    );

    test('signIn() викликає сервіс і повертає акаунт напряму', () async {
      when(() => mockAuthService.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAuthService.currentUser).thenReturn(null);

      final container = createContainer();
      await container.read(authControllerProvider.future);

      final result = await container
          .read(authControllerProvider.notifier)
          .signIn();

      // Перевіряємо тільки те, за що тепер відповідає метод signIn
      verify(() => mockAuthService.signIn()).called(1);
      expect(result, mockAccount);
    });

    test(
      'signIn() перехоплює помилки і переводить стан в AsyncError',
      () async {
        final exception = Exception('Вхід скасовано');

        when(() => mockAuthService.currentUser).thenReturn(null);
        when(
          () => mockAuthService.signIn(),
        ).thenAnswer((_) async => throw exception);

        final container = createContainer();
        await container.read(authControllerProvider.future);

        final result = await container
            .read(authControllerProvider.notifier)
            .signIn();

        final state = container.read(authControllerProvider);

        expect(state.hasError, isTrue);
        expect(state.error, exception);
        expect(result, isNull);

        // Переконуємось, що при помилці кеш не оновлювався
        verifyNever(() => mockPrefs.setBool(authFlagKey, true));
      },
    );

    test('signOut() викликає сервіс', () async {
      when(() => mockAuthService.currentUser).thenReturn(mockAccount);
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final container = createContainer();
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).signOut();

      // Метод signOut тепер тільки дергає сервіс, а очищенням займається потік
      verify(() => mockAuthService.signOut()).called(1);
    });
  });
}
