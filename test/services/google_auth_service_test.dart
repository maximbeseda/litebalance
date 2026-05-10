import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:coin_flow/services/google_auth_service.dart';

// 👇 FAKE з точними сигнатурами версії 7.2.0
class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? mockAccount;
  bool shouldThrow = false;

  @override
  Future<void> initialize({
    String? clientId,
    String? hostedDomain,
    String? nonce,
    String? serverClientId,
  }) async {
    // Метод ініціалізації у 7.2.0 змінив параметри
  }

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

class MockAccount extends Mock implements GoogleSignInAccount {}

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
      fakeGoogleSignIn.mockAccount = account;

      final result = await authService.signIn();

      expect(result, equals(account));
      expect(authService.currentUser, equals(account));
    });

    test('signIn повертає null, якщо виникає помилка або скасування', () async {
      // Оскільки authenticate тепер non-nullable, ми імітуємо скасування через помилку,
      // яку твій сервіс ловить у блоці catch і повертає null.
      fakeGoogleSignIn.shouldThrow = true;

      final result = await authService.signIn();

      expect(result, isNull);
    });

    test(
      'signInSilently повертає акаунт через attemptLightweightAuthentication',
      () async {
        final account = MockAccount();
        fakeGoogleSignIn.mockAccount = account;

        final result = await authService.signInSilently();

        expect(result, equals(account));
      },
    );

    test('signOut очищує стан currentUser', () async {
      fakeGoogleSignIn.mockAccount = MockAccount();
      // Спочатку "логінимо" юзера в сервіс
      await authService.signIn();

      await authService.signOut();

      expect(authService.currentUser, isNull);
    });
  });
}
