import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:coin_flow/services/google_auth_service.dart';

// 1. Створюємо "фальшиві" класи для інструментів Google
class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockGoogleSignIn mockGoogleSignIn;
  late GoogleAuthService authService;

  setUp(() {
    // 2. Перед кожним тестом створюємо чисті об'єкти
    mockGoogleSignIn = MockGoogleSignIn();

    // 3. Передаємо фальшивий об'єкт у наш сервіс завдяки оновленому конструктору!
    authService = GoogleAuthService(googleSignIn: mockGoogleSignIn);
  });

  group('GoogleAuthService Tests', () {
    test('signIn повертає обліковий запис при успішній авторизації', () async {
      // Готуємо фальшивий акаунт, який ми "отримаємо" від Google
      final mockAccount = MockGoogleSignInAccount();

      // Вчимо наш мок-об'єкт, як відповідати на виклики методів
      when(
        () => mockGoogleSignIn.initialize(
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockGoogleSignIn.attemptLightweightAuthentication(),
      ).thenAnswer((_) async => mockAccount); // Успішний вхід

      // Виконуємо метод
      final result = await authService.signIn();

      // Перевіряємо, чи повернувся наш акаунт
      expect(result, isNotNull);
      expect(result, equals(mockAccount));
    });

    test('signIn повертає null, якщо виникає помилка', () async {
      // Вчимо мок-об'єкт викидати помилку (наприклад, немає інтернету)
      when(
        () => mockGoogleSignIn.initialize(
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockGoogleSignIn.attemptLightweightAuthentication(),
      ).thenThrow(Exception('No internet'));

      final result = await authService.signIn();

      // Сервіс має зловити помилку в блоці catch і повернути null
      expect(result, isNull);
    });

    test('signOut коректно викликає метод виходу', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      // Перевіряємо, чи наш сервіс дійсно дав команду Google вийти з акаунту
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });
  });
}
