import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'all_providers.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  static const String _authFlagKey = 'has_logged_in_with_google';

  @override
  FutureOr<GoogleSignInAccount?> build() async {
    final authService = ref.watch(googleAuthServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final subscription = authService.authStateChanges.listen((account) {
      // 👇 ГРАНД-ФІКС 1: Оновлюємо стан Riverpod МИТТЄВО, без жодних await!
      // Додаток переключить Onboarding на HomeScreen в ту ж мілісекунду, коли Google дасть акаунт.
      state = AsyncData(account);

      // 👇 Запис у SharedPreferences робимо паралельно у фоні. Кеш у RAM оновиться відразу.
      if (account != null) {
        prefs.setBool(_authFlagKey, true);
        prefs.setString(
          'google_user_name',
          account.displayName ?? 'Google User',
        );
        prefs.setString('google_user_email', account.email);
        if (account.photoUrl != null) {
          prefs.setString('google_user_photo', account.photoUrl!);
        }
      } else {
        prefs.setBool(_authFlagKey, false);
        prefs.remove('google_user_name');
        prefs.remove('google_user_email');
        prefs.remove('google_user_photo');
      }
    });

    ref.onDispose(() => subscription.cancel());

    return authService.currentUser;
  }

  // 👇 ФІКС: Тепер метод повертає GoogleSignInAccount? безпосередньо!
  Future<GoogleSignInAccount?> signIn() async {
    state = const AsyncLoading();
    final authService = ref.read(googleAuthServiceProvider);

    try {
      final account = await authService.signIn();
      return account;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final authService = ref.read(googleAuthServiceProvider);

    try {
      await authService.signOut();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
