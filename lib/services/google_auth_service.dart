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

  // 👇 НОВЕ: Ручне кешування стану для версії пакета 7.0+
  GoogleSignInAccount? _currentUser;
  final StreamController<GoogleSignInAccount?> _authStateController =
      StreamController<GoogleSignInAccount?>.broadcast();

  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  // Віддаємо інформацію назовні
  GoogleSignInAccount? get currentUser => _currentUser;
  Stream<GoogleSignInAccount?> get authStateChanges =>
      _authStateController.stream;

  Future<void> init() async {
    await _googleSignIn.initialize(serverClientId: _serverClientId);
  }

  // Допоміжний метод для оновлення стану
  void _updateUser(GoogleSignInAccount? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  // Тиха авторизація (v7.0+ використовує attemptLightweightAuthentication)
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      await init();
      final account = await _googleSignIn.attemptLightweightAuthentication();
      _updateUser(account);
      return account;
    } catch (e) {
      log('Google Auth Silent Sign In Error: $e', name: 'GoogleAuthService');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await init();
      var account = await _googleSignIn.attemptLightweightAuthentication();
      // v7.0+ використовує authenticate
      account ??= await _googleSignIn.authenticate();
      _updateUser(account);
      return account;
    } catch (e) {
      log('Google Auth Error: $e', name: 'GoogleAuthService');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _updateUser(null); // Очищаємо кеш при виході
    } catch (e) {
      log('Google Auth Sign Out Error: $e', name: 'GoogleAuthService');
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    try {
      // Використовуємо наш локальний кеш
      var account = currentUser ?? await signInSilently();
      account ??= await signIn();

      if (account == null) return null;

      final authClient = account.authorizationClient;
      var authz = await authClient.authorizationForScopes(_scopes);
      authz ??= await authClient.authorizeScopes(_scopes);

      return authz.authClient(scopes: _scopes);
    } catch (e) {
      log('Authenticated Client Error: $e', name: 'GoogleAuthService');
      return null;
    }
  }
}
