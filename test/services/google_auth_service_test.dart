import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Зверни увагу: імпорт extension_google_sign_in_as_googleapis_auth потрібен для роботи сервісу, але не для моку.

import 'package:coin_flow/services/google_auth_service.dart';

// ==========================================
// МОКИ ТА ЗАГЛУШКИ
// ==========================================

class MockAccount extends Mock implements GoogleSignInAccount {}

class MockAuthClient extends Mock implements GoogleSignInAuthorizationClient {}

class MockClientAuth extends Mock implements GoogleSignInClientAuthorization {}

// Моки для подій стріму GoogleSignIn (v7.x)
class MockSignInEvent extends Mock
    implements GoogleSignInAuthenticationEventSignIn {}

class MockSignOutEvent extends Mock
    implements GoogleSignInAuthenticationEventSignOut {}

// Розширений Fake для версії 7.2.0, який імітує весь функціонал
class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? mockAccount;
  bool shouldThrow = false;
  bool lightweightReturnsNull = false;
  bool shouldThrowOnDisconnect = false;

  final StreamController<GoogleSignInAuthenticationEvent> streamController =
      StreamController<GoogleSignInAuthenticationEvent>.broadcast();

  // Глобальний клієнт авторизації (для тихих запитів)
  final MockAuthClient globalAuthClient = MockAuthClient();

  @override
  Future<void> initialize({
    String? clientId,
    String? hostedDomain,
    String? nonce,
    String? serverClientId,
  }) async {}

  @override
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      streamController.stream;

  @override
  GoogleSignInAuthorizationClient get authorizationClient => globalAuthClient;

  @override
  Future<GoogleSignInAccount?> attemptLightweightAuthentication({
    bool reportAllExceptions = false,
  }) async {
    if (shouldThrow) throw Exception('Auth Error');
    if (lightweightReturnsNull) return null;
    return mockAccount;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    if (shouldThrow || mockAccount == null) {
      throw Exception('Authentication failed or cancelled');
    }
    return mockAccount!;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    return null;
  }

  @override
  Future<void> disconnect() async {
    if (shouldThrowOnDisconnect) throw Exception('Disconnect error');
  }
}

void main() {
  late FakeGoogleSignIn fakeGoogleSignIn;
  late GoogleAuthService authService;

  setUp(() {
    fakeGoogleSignIn = FakeGoogleSignIn();
    authService = GoogleAuthService(googleSignIn: fakeGoogleSignIn);
  });

  tearDown(() {
    fakeGoogleSignIn.streamController.close();
  });

  group('GoogleAuthService - 100% Coverage', () {
    // --- ТЕСТИ ІНІЦІАЛІЗАЦІЇ ТА СТРІМІВ ---
    test('init() слухає стрім подій і оновлює currentUser', () async {
      await authService.init();

      final mockAccount = MockAccount();
      final signInEvent = MockSignInEvent();
      when(() => signInEvent.user).thenReturn(mockAccount);

      // Імітуємо подію входу
      fakeGoogleSignIn.streamController.add(signInEvent);
      await Future.delayed(Duration.zero);
      expect(authService.currentUser, mockAccount);

      // Імітуємо подію виходу
      final signOutEvent = MockSignOutEvent();
      fakeGoogleSignIn.streamController.add(signOutEvent);
      await Future.delayed(Duration.zero);
      expect(authService.currentUser, isNull);

      // Імітуємо помилку в стрімі (має бути оброблена в onError без крешів)
      fakeGoogleSignIn.streamController.addError(Exception('Stream Error'));
      await Future.delayed(Duration.zero); // Тест не впаде завдяки onError
    });

    // --- ТЕСТИ SIGN IN / SIGN OUT ---
    test('signIn() повертає акаунт при успішній авторизації', () async {
      final account = MockAccount();
      fakeGoogleSignIn.mockAccount = account;

      final result = await authService.signIn();
      expect(result, equals(account));
    });

    test('signIn() повертає null при помилці', () async {
      fakeGoogleSignIn.shouldThrow = true;
      final result = await authService.signIn();
      expect(result, isNull);
    });

    test('signOut() очищує акаунт', () async {
      final account = MockAccount();
      fakeGoogleSignIn.mockAccount = account;

      await authService.signIn(); // Примусово "логінимо"
      await authService.signOut();

      expect(authService.currentUser, isNull);
    });

    test('clearTokenAndSignOut() робить disconnect і очищає дані', () async {
      await authService.clearTokenAndSignOut();
      expect(authService.currentUser, isNull);

      // Перевірка перехоплення помилки (тест не має впасти)
      fakeGoogleSignIn.shouldThrowOnDisconnect = true;
      await authService.clearTokenAndSignOut();
    });

    // --- ТЕСТИ GET AUTHENTICATED CLIENT ---
    test('getAuthenticatedClient: Глобальний тихий запит успішний', () async {
      final clientAuth = MockClientAuth();

      // 👇 ФІКС: Замість імітації розширення, ми просто даємо токен,
      // і розширення саме створить клієнт!
      when(() => clientAuth.accessToken).thenReturn('fake_token');

      when(
        () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
      ).thenAnswer((_) async => clientAuth);

      final result = await authService.getAuthenticatedClient();
      expect(result, isNotNull); // Клієнт створений!
    });

    test(
      'getAuthenticatedClient: Глобальний запит впав, інтерактивний режим ЗАБОРОНЕНО',
      () async {
        when(
          () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => throw Exception('Silent Global Error'));

        final result = await authService.getAuthenticatedClient(
          allowInteractive: false,
        );
        expect(result, isNull);
      },
    );

    test(
      'getAuthenticatedClient: Lightweight Auth + Тихий запит акаунта успішні',
      () async {
        when(
          () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => null);

        final account = MockAccount();
        final authClient = MockAuthClient();
        final clientAuth = MockClientAuth();

        when(() => account.authorizationClient).thenReturn(authClient);
        when(
          () => authClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => clientAuth);

        // 👇 ФІКС: Даємо токен
        when(() => clientAuth.accessToken).thenReturn('fake_token');

        fakeGoogleSignIn.mockAccount = account;

        final result = await authService.getAuthenticatedClient();
        expect(result, isNotNull);
      },
    );

    test(
      'getAuthenticatedClient: Fallback на Authenticate + Інтерактивний запит акаунта',
      () async {
        when(
          () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => null);

        final account = MockAccount();
        final authClient = MockAuthClient();
        final clientAuth = MockClientAuth();

        when(() => account.authorizationClient).thenReturn(authClient);
        when(
          () => authClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => throw Exception('Silent Acc Error'));
        when(
          () => authClient.authorizeScopes(any()),
        ).thenAnswer((_) async => clientAuth);

        // 👇 ФІКС: Даємо токен
        when(() => clientAuth.accessToken).thenReturn('fake_token');

        fakeGoogleSignIn.mockAccount = account;
        fakeGoogleSignIn.lightweightReturnsNull =
            true; // Форсуємо виклик authenticate()

        final result = await authService.getAuthenticatedClient();
        expect(result, isNotNull);
      },
    );

    test(
      'getAuthenticatedClient: Помилка або скасування на екрані авторизації (One Tap)',
      () async {
        when(
          () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => null);

        fakeGoogleSignIn.shouldThrow = true;

        final result = await authService.getAuthenticatedClient();
        expect(result, isNull);
      },
    );

    test(
      'getAuthenticatedClient: Помилка на етапі запиту прав на Диск',
      () async {
        when(
          () => fakeGoogleSignIn.globalAuthClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => null);

        final account = MockAccount();
        final authClient = MockAuthClient();

        when(() => account.authorizationClient).thenReturn(authClient);
        when(
          () => authClient.authorizationForScopes(any()),
        ).thenAnswer((_) async => null);
        when(
          () => authClient.authorizeScopes(any()),
        ).thenAnswer((_) async => throw Exception('User denied permissions'));

        fakeGoogleSignIn.mockAccount = account;

        final result = await authService.getAuthenticatedClient();
        expect(result, isNull);
      },
    );
  });
}
