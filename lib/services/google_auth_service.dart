import 'dart:developer';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  // 👇 Web Client ID з Google Cloud Console
  static const String _serverClientId =
      '711001679852-cmf3msj3a8re2c9cq4pefvbntr8vcomp.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final List<String> _scopes = [drive.DriveApi.driveAppdataScope];

  Future<void> init() async {
    await _googleSignIn.initialize(serverClientId: _serverClientId);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await init();
      var account = await _googleSignIn.attemptLightweightAuthentication();
      account ??= await _googleSignIn.authenticate();
      return account;
    } catch (e) {
      log('Google Auth Error: $e', name: 'GoogleAuthService');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<http.Client?> getAuthenticatedClient() async {
    try {
      final account = await signIn();
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
