import 'dart:async';
import 'dart:developer';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  static const String _serverClientId =
      '711001679852-cmf3msj3a8re2c9cq4pefvbntr8vcomp.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn;
  final List<String> _scopes = [drive.DriveApi.driveAppdataScope];

  GoogleSignInAccount? _currentUser;
  final StreamController<GoogleSignInAccount?> _authStateController =
      StreamController<GoogleSignInAccount?>.broadcast();

  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  GoogleSignInAccount? get currentUser => _currentUser;
  Stream<GoogleSignInAccount?> get authStateChanges =>
      _authStateController.stream;

  Future<void> init() async {
    await _googleSignIn.initialize(serverClientId: _serverClientId);

    // 👇 ФІКС 1: Використовуємо новий потік подій для 7-ї версії
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _updateUser(event.user);
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _updateUser(null);
      }
    });
  }

  void _updateUser(GoogleSignInAccount? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  Future<http.Client?> getAuthenticatedClient({
    bool allowInteractive = true,
  }) async {
    try {
      await init();

      // 1. Спочатку спроба АБСОЛЮТНО ТИХО (без пробудження UI)
      final globalAuthClient = _googleSignIn.authorizationClient;
      final silentAuthz = await globalAuthClient.authorizationForScopes(
        _scopes,
      );

      if (silentAuthz != null) {
        log('✅ Токени отримано тихо', name: 'GoogleAuthService');
        return silentAuthz.authClient(scopes: _scopes);
      }

      // 2. Якщо тихо не вийшло і ми в АВТО-режимі -> виходимо (засвітиться червона крапка)
      if (!allowInteractive) {
        log(
          '⚠️ Авто-режим: токени відсутні. UI заблоковано.',
          name: 'GoogleAuthService',
        );
        return null;
      }

      // 3. ІНТЕРАКТИВНИЙ РЕЖИМ (Користувач натиснув кнопку)
      log(
        '🔄 Спроба інтерактивного відновлення сесії...',
        name: 'GoogleAuthService',
      );

      // 👇 ФІКС 1: Беремо поточного юзера. Якщо його немає (стерли через помилку 401) - викликаємо signIn()
      final account = _currentUser ?? await signIn();

      if (account == null) {
        log(
          '❌ Користувач скасував вхід або сталася помилка',
          name: 'GoogleAuthService',
        );
        return null;
      }

      // 👇 ФІКС 2: Використовуємо authorizeScopes (ІНТЕРАКТИВНИЙ), а не authorizationForScopes (ТИХИЙ)
      // Це гарантує, що якщо дозволів на Диск немає, користувач побачить вікно із запитом!
      final interactiveAuthz = await account.authorizationClient
          .authorizeScopes(_scopes);

      return interactiveAuthz.authClient(scopes: _scopes);
    } catch (e) {
      log('❌ Критична помилка авторизації: $e', name: 'GoogleAuthService');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await init();

      var account = await _googleSignIn.attemptLightweightAuthentication();

      account ??= await _googleSignIn.authenticate();

      await account.authorizationClient.authorizeScopes(_scopes);

      return account;
    } catch (e) {
      log('❌ Помилка входу: $e', name: 'GoogleAuthService');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _updateUser(null);
    } catch (e) {
      log('❌ Помилка виходу: $e', name: 'GoogleAuthService');
    }
  }

  // 👇 Метод для примусового очищення зламаних токенів
  Future<void> clearTokenAndSignOut() async {
    log('⚠️ Примусове очищення токенів та вихід...', name: 'GoogleAuthService');
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect(); // Повністю відв'язує акаунт
      _updateUser(null);
    } catch (e) {
      log('❌ Помилка очищення: $e', name: 'GoogleAuthService');
    }
  }
}
