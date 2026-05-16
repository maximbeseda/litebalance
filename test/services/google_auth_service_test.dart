import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:coin_flow/services/google_auth_service.dart';

// 👇 FAKE з точними сигнатурами версії 7.2.0 та новим потоком подій
class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? mockAccount;
  bool shouldThrow = false;

  @override
  Future<void> initialize({
    String? clientId,
    String? hostedDomain,
    String? nonce,
    String? serverClientId,
  }) async {}

  // Обов'язкова заглушка для нового потоку подій v7.x
  @override
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      const Stream.empty();

  @override
  Future<GoogleSignInAccount?> attemptLightweightAuthentication({
    bool reportAllExceptions = false,
  }) async {
    if (shouldThrow) throw Exception('Auth Error');
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
}

// Заглушки для перевірки Scopes (доступу до Диску)
class MockAccount extends Mock implements GoogleSignInAccount {}

class MockAuthClient extends Mock implements GoogleSignInAuthorizationClient {}

class MockClientAuth extends Mock implements GoogleSignInClientAuthorization {}

void main() {
  late FakeGoogleSignIn fakeGoogleSignIn;
  late GoogleAuthService authService;

  setUp(() {
    fakeGoogleSignIn = FakeGoogleSignIn();
    authService = GoogleAuthService(googleSignIn: fakeGoogleSignIn);
  });

  group('GoogleAuthService - Fixed Fake 7.2.0', () {
    test('signIn повертає акаунт при успішній авторизації', () async {
      final account = MockAccount();
      final authClient = MockAuthClient();
      final clientAuth = MockClientAuth();

      // Навчаємо мок відповідати на запити доступу до Диску
      when(() => account.authorizationClient).thenReturn(authClient);
      when(
        () => authClient.authorizeScopes(any()),
      ).thenAnswer((_) async => clientAuth);

      fakeGoogleSignIn.mockAccount = account;

      final result = await authService.signIn();

      expect(result, equals(account));
    });

    test('signIn повертає null, якщо виникає помилка або скасування', () async {
      fakeGoogleSignIn.shouldThrow = true;

      final result = await authService.signIn();

      expect(result, isNull);
    });

    // ❌ Тест signInSilently повністю видалено, оскільки метод більше не існує

    test('signOut очищує стан currentUser', () async {
      final account = MockAccount();
      final authClient = MockAuthClient();
      final clientAuth = MockClientAuth();

      when(() => account.authorizationClient).thenReturn(authClient);
      when(
        () => authClient.authorizeScopes(any()),
      ).thenAnswer((_) async => clientAuth);

      fakeGoogleSignIn.mockAccount = account;

      // Спочатку "логінимо" юзера в сервіс
      await authService.signIn();

      await authService.signOut();

      expect(authService.currentUser, isNull);
    });
  });
}
