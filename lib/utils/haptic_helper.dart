import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Єдина точка тактильного відгуку. Сам перевіряє налаштування
/// "haptic_feedback_enabled" і наявність вібромотора, тож виклик нічого
/// не робить, якщо користувач вимкнув вібрацію.
class HapticHelper {
  HapticHelper._();

  static SharedPreferences? _prefs;
  static bool _hasVibrator = false;
  static bool _vibratorChecked = false;

  static Future<void> _impact(int duration, int amplitude) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!(_prefs!.getBool('haptic_feedback_enabled') ?? true)) return;

    if (!_vibratorChecked) {
      _hasVibrator = await Vibration.hasVibrator();
      _vibratorChecked = true;
    }
    if (_hasVibrator) {
      unawaited(Vibration.vibrate(duration: duration, amplitude: amplitude));
    }
  }

  /// Легкий відгук (натискання клавіш, дрібні дії).
  static Future<void> light() => _impact(15, 30);

  /// Середній відгук (підтвердження, перемикання).
  static Future<void> medium() => _impact(18, 60);

  /// Сильний відгук (помилки, важливі/незворотні дії).
  static Future<void> heavy() => _impact(30, 120);
}
