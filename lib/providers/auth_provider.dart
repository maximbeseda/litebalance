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

    // Підписуємося на події зміни акаунту
    final subscription = authService.authStateChanges.listen((account) {
      state = AsyncData(account);
    });

    ref.onDispose(() => subscription.cancel());

    // 👇 ГОЛОВНИЙ ФІКС: Більше ніяких викликів авторизації при старті!
    // Ми покладаємось на SharedPreferences для показу аватарки в UI,
    // а коли почнеться фоновий бекап, GoogleAuthService тихо дістане токен сам.

    return authService.currentUser;
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    final authService = ref.read(googleAuthServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    try {
      final account = await authService.signIn();

      if (account != null) {
        await prefs.setBool(_authFlagKey, true);
        await prefs.setString(
          'google_user_name',
          account.displayName ?? 'Google User',
        );
        await prefs.setString('google_user_email', account.email);
        if (account.photoUrl != null) {
          await prefs.setString('google_user_photo', account.photoUrl!);
        }
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final authService = ref.read(googleAuthServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    try {
      await authService.signOut();

      await prefs.setBool(_authFlagKey, false);
      await prefs.remove('google_user_name');
      await prefs.remove('google_user_email');
      await prefs.remove('google_user_photo');
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
