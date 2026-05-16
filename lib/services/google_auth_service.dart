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

  // 👇 ЗАХИСТ: Прапорець, щоб не викликати ініціалізацію та listen() двічі
  bool _isInitialized = false;

  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  GoogleSignInAccount? get currentUser => _currentUser;
  Stream<GoogleSignInAccount?> get authStateChanges =>
      _authStateController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    await _googleSignIn.initialize(serverClientId: _serverClientId);

    _googleSignIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _updateUser(event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _updateUser(null);
        }
      },
      // 👇 ГОЛОВНИЙ АРХІТЕКТУРНИЙ ФІКС ДЛЯ ЗНИЩЕННЯ КРАШІВ (Signal 3)
      // Обов'язково глушимо помилки скасування на рівні глобального стріму плагіна.
      // Тепер при скасуванні помилка не буде «вішати» платформений канал.
      onError: (error) {
        log(
          '⚠️ Оброблено помилку у стрімі подій Google: $error',
          name: 'GoogleAuthService',
        );
      },
    );

    _isInitialized = true;
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

      try {
        final silentAuthz = await globalAuthClient.authorizationForScopes(
          _scopes,
        );
        if (silentAuthz != null) {
          log('✅ Токени отримано тихо (global)', name: 'GoogleAuthService');
          return silentAuthz.authClient(scopes: _scopes);
        }
      } catch (e) {
        log(
          '⚠️ Тихий глобальний запит повернув помилку: $e',
          name: 'GoogleAuthService',
        );
      }

      // 2. Якщо тихо не вийшло і ми в АВТО-режимі -> виходимо
      if (!allowInteractive) {
        log(
          '⚠️ Авто-режим: токени відсутні. Фоновий запит скасовано.',
          name: 'GoogleAuthService',
        );
        return null;
      }

      // 3. ІНТЕРАКТИВНИЙ РЕЖИМ (Користувач натиснув кнопку)
      log(
        '🔄 Спроба викликати швидкий вхід One Tap для синхронізації...',
        name: 'GoogleAuthService',
      );

      GoogleSignInAccount? account = _currentUser;

      if (account == null) {
        try {
          final lightweightAccount = await _googleSignIn
              .attemptLightweightAuthentication(reportAllExceptions: true);

          // 👇 ФІКС 1: Використовуємо нуль-важливе надання значень (??=), як просив лінтер.
          // Оскільки authenticate() non-nullable, змінна `account` гарантовано заповниться.
          account = lightweightAccount ?? await _googleSignIn.authenticate();

          // 👇 ФІКС 2: Прибрали if (account != null), бо Dart і так знає, що він тут НЕ null.
          _updateUser(account);
        } catch (e) {
          log(
            '⚠️ Користувач скасував вікно One Tap для синхронізації або сталася помилка: $e',
            name: 'GoogleAuthService',
          );
          return null;
        }
      }

      // 👇 ФІКС 3: Прибрали if (account == null) return null;, який викликав Dead Code.
      // Якщо ми дожили до цього рядка, Dart на 200% впевнений, що account має значення.

      // 4. Спочатку робимо ТИХУ перевірку прав на Диск для КОНКРЕТНОГО акаунта
      try {
        final accountSilentAuthz = await account.authorizationClient
            .authorizationForScopes(_scopes);
        if (accountSilentAuthz != null) {
          log(
            '✅ Дозволи на Диск вже були надані раніше.',
            name: 'GoogleAuthService',
          );
          return accountSilentAuthz.authClient(scopes: _scopes);
        }
      } catch (e) {
        log(
          '⚠️ Тиха перевірка дозволів не вдалася: $e',
          name: 'GoogleAuthService',
        );
      }

      // 5. Тільки якщо попередній тихий крок сказав, що прав немає — ЗАПИТУЄМО ІНТЕРАКТИВНО.
      log(
        '🛡️ Запит прав доступу до Google Drive...',
        name: 'GoogleAuthService',
      );
      final interactiveAuthz = await account.authorizationClient
          .authorizeScopes(_scopes);

      return interactiveAuthz.authClient(scopes: _scopes);
    } catch (e) {
      log(
        '❌ Критична помилка або скасування прав на Диск: $e',
        name: 'GoogleAuthService',
      );
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await init();

      // 👇 Згідно з практиками Google: для кнопок використовується тільки authenticate().
      // Це дає користувачу повний вибір усіх його Google-акаунтів на пристрої.
      // Якщо він натисне "Скасувати", метод просто викине помилку, ми її зловимо і повернемо null.
      final account = await _googleSignIn.authenticate();

      return account;
    } catch (e) {
      log(
        '❌ Користувач скасував вхід на екрані: $e',
        name: 'GoogleAuthService',
      );
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
