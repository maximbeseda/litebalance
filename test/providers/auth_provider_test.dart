import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Правильні імпорти
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/google_auth_service.dart';

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockGoogleAuthService mockAuthService;
  late MockSharedPreferences mockPrefs;
  late MockGoogleSignInAccount mockAccount;

  const String authFlagKey = 'has_logged_in_with_google';

  setUp(() {
    mockAuthService = MockGoogleAuthService();
    mockPrefs = MockSharedPreferences();
    mockAccount = MockGoogleSignInAccount();

    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());

    // Базові налаштування кешу
    when(() => mockPrefs.getBool(any())).thenReturn(false);
    when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
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
    // 👇 НОВИЙ ТЕСТ ДЛЯ BUILD, який відповідає реальному коду
    test(
      'build() повертає поточного юзера та підписується на authStateChanges',
      () async {
        // Імітуємо, що в сервісі лежить якийсь користувач
        when(() => mockAuthService.currentUser).thenReturn(mockAccount);

        // Налаштовуємо потік, щоб перевірити реактивність
        final streamController = StreamController<GoogleSignInAccount?>();
        when(
          () => mockAuthService.authStateChanges,
        ).thenAnswer((_) => streamController.stream);

        final container = createContainer();
        final result = await container.read(authControllerProvider.future);

        // 1. build() повинен повернути те, що лежить у currentUser
        expect(result, mockAccount);

        // 2. Якщо в потік прилітає null (наприклад, юзер розлогінився десь інде)
        streamController.add(null);
        await Future.delayed(Duration.zero); // чекаємо оновлення стріма

        // Стан провайдера має оновитися на null
        expect(container.read(authControllerProvider).value, isNull);

        await streamController.close();
      },
    );

    test('signIn() успішно зберігає дані в SharedPreferences', () async {
      when(() => mockAccount.displayName).thenReturn('Максим');
      when(() => mockAccount.email).thenReturn('max@test.com');
      when(() => mockAccount.photoUrl).thenReturn('https://photo.url');

      when(() => mockAuthService.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockAuthService.currentUser).thenReturn(null);

      final container = createContainer();
      await container.read(authControllerProvider.future); // Чекаємо build

      await container.read(authControllerProvider.notifier).signIn();

      verify(() => mockAuthService.signIn()).called(1);
      verify(() => mockPrefs.setBool(authFlagKey, true)).called(1);
      verify(() => mockPrefs.setString('google_user_name', 'Максим')).called(1);
      verify(
        () => mockPrefs.setString('google_user_email', 'max@test.com'),
      ).called(1);
      verify(
        () => mockPrefs.setString('google_user_photo', 'https://photo.url'),
      ).called(1);
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
        await container.read(authControllerProvider.future); // Чекаємо build

        await container.read(authControllerProvider.notifier).signIn();

        final state = container.read(authControllerProvider);

        expect(state.hasError, isTrue);
        expect(state.error, exception);

        // Переконуємось, що при помилці кеш не оновлювався
        verifyNever(() => mockPrefs.setBool(authFlagKey, true));
      },
    );

    test('signOut() викликає сервіс і очищає SharedPreferences', () async {
      when(() => mockAuthService.currentUser).thenReturn(mockAccount);
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final container = createContainer();
      await container.read(authControllerProvider.future); // Чекаємо build

      await container.read(authControllerProvider.notifier).signOut();

      verify(() => mockAuthService.signOut()).called(1);
      verify(() => mockPrefs.setBool(authFlagKey, false)).called(1);
      verify(() => mockPrefs.remove('google_user_name')).called(1);
      verify(() => mockPrefs.remove('google_user_email')).called(1);
      verify(() => mockPrefs.remove('google_user_photo')).called(1);
    });
  });
}
