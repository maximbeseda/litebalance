import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/app_lock.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _pinKey = 'user_secure_pin_hash';
  static const String _biometricsEnabledKey = 'use_biometrics';

  // Сіль для ускладнення підбору PIN-коду
  static const String _pinSalt = 'CoinFlow_Secure_Salt_2026';

  static Future<bool> canUseBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Помилка перевірки біометрії: $e');
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics(String localizedReason) async {
    try {
      // Підбираємо підказку залежно від доступного типу біометрії
      // (Face ID — інша фраза, ніж для відбитка).
      final available = await _auth.getAvailableBiometrics();
      final bool isFace =
          available.contains(BiometricType.face) &&
          !available.contains(BiometricType.fingerprint);
      final String hint = isFace
          ? 'biometric_hint_face'.tr()
          : 'biometric_hint'.tr();

      // Обгортаємо в runTrusted, щоб системний діалог біометрії (який згортає
      // застосунок у inactive/paused) не вмикав privacy-шторку AppLockGate.
      return await AppLock.runTrusted(
        () => _auth.authenticate(
          localizedReason: localizedReason,
          authMessages: [
            AndroidAuthMessages(
              signInTitle: 'biometric_title'.tr(),
              signInHint: hint,
              cancelButton: 'use_pin_code'.tr(),
            ),
            IOSAuthMessages(cancelButton: 'use_pin_code'.tr()),
          ],
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        ),
      );
    } catch (e) {
      debugPrint('Помилка авторизації: $e');
      return false;
    }
  }

  static Future<void> setBiometricsEnabled(bool isEnabled) async {
    await _secureStorage.write(
      key: _biometricsEnabledKey,
      value: isEnabled.toString(),
    );
  }

  static Future<bool> isBiometricsEnabled() async {
    final value = await _secureStorage.read(key: _biometricsEnabledKey);
    return value == 'true';
  }

  // Єдиний, безпечний метод генерації ключа (10 000 ітерацій)
  static Uint8List _deriveKeySecure(String pin) {
    List<int> bytes = utf8.encode(pin + _pinSalt);
    for (int i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return Uint8List.fromList(bytes);
  }

  static Future<void> setPinCode(String pin) async {
    final keyBytes = _deriveKeySecure(pin);
    final hashToStore = base64Encode(keyBytes);
    await _secureStorage.write(key: _pinKey, value: hashToStore);
  }

  static Future<bool> verifyPinCode(String enteredPin) async {
    final storedHash = await _secureStorage.read(key: _pinKey);
    if (storedHash == null) return false;

    final secureKeyBytes = _deriveKeySecure(enteredPin);
    final secureHash = base64Encode(secureKeyBytes);

    return storedHash == secureHash;
  }

  static Future<bool> isPinSet() async {
    final storedHash = await _secureStorage.read(key: _pinKey);
    return storedHash != null;
  }

  static Future<void> disableSecurity() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _biometricsEnabledKey);
  }
}
