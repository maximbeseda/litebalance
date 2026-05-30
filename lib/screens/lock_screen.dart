import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../theme/app_colors_extension.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  final bool isSetupMode;

  const LockScreen({super.key, this.isSetupMode = false});

  static bool isShowing = false;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstPin = ''; // Для підтвердження при створенні
  bool _isConfirming = false;
  bool _hasError = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    LockScreen.isShowing = true;
    _checkBiometrics();
  }

  @override
  void dispose() {
    LockScreen.isShowing = false;
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    if (widget.isSetupMode) return;

    final isEnabledInSettings = await SecurityService.isBiometricsEnabled();
    final canUse = await SecurityService.canUseBiometrics();

    if (isEnabledInSettings && canUse) {
      setState(() => _canUseBiometrics = true);
      await _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    final success = await SecurityService.authenticateWithBiometrics(
      'auth_reason'.tr(),
    );
    if (success && mounted) {
      _unlockApp();
    }
  }

  void _onKeyPressed(String key) {
    if (_pin.length >= 4 && key != 'backspace') return;

    setState(() {
      _hasError = false; // Скидаємо помилку при новому вводі
      if (key == 'backspace') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        _pin += key;
      }
    });

    if (_pin.length == 4) {
      // Невелика затримка, щоб користувач встиг побачити заповнений останній кружечок
      Future.delayed(const Duration(milliseconds: 150), () => _processPin());
    }
  }

  Future<void> _processPin() async {
    if (widget.isSetupMode) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstPin) {
          await SecurityService.setPinCode(_pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          _showError();
        }
      }
    } else {
      final isCorrect = await SecurityService.verifyPinCode(_pin);
      if (isCorrect) {
        _unlockApp();
      } else {
        _showError();
      }
    }
  }

  void _showError() {
    HapticFeedback.heavyImpact();
    setState(() {
      _hasError = true;
      _pin = '';
      if (widget.isSetupMode) {
        _isConfirming = false;
        _firstPin = '';
      }
    });
  }

  void _unlockApp() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    FocusManager.instance.primaryFocus?.unfocus();

    final String title = widget.isSetupMode
        ? (_isConfirming ? 'confirm_pin'.tr() : 'create_pin'.tr())
        : 'enter_pin'.tr();

    return Scaffold(
      backgroundColor: colors.cardBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Плавна анімація дрижання при помилці
            TweenAnimationBuilder<double>(
              key: ValueKey(_hasError),
              tween: Tween(begin: 0.0, end: _hasError ? 1.0 : 0.0),
              duration: const Duration(
                milliseconds: 250,
              ), // Зменшили час (було 350)
              builder: (context, value, child) {
                // math.pi * 6 = 3 швидких коливання замість 2
                final offset = _hasError
                    ? math.sin(value * math.pi * 6) * 5
                    : 0.0;

                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: _hasError ? colors.expense : colors.textMain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _hasError ? colors.expense : colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Кружечки для ПІН-коду
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final bool isFilled = index < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? (_hasError ? colors.expense : colors.accent)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isFilled
                                    ? (_hasError
                                          ? colors.expense
                                          : colors.accent)
                                    : colors.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(),

            // Клавіатура
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) {
                    return _canUseBiometrics
                        ? _buildKey(context, 'bio', icon: Icons.fingerprint)
                        : const SizedBox();
                  }
                  if (index == 10) return _buildKey(context, '0');
                  if (index == 11) {
                    return _buildKey(
                      context,
                      'backspace',
                      icon: Icons.backspace_outlined,
                    );
                  }
                  return _buildKey(context, '${index + 1}');
                },
              ),
            ),

            // Повноширока кнопка Скасувати
            if (widget.isSetupMode)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'cancel'.tr(),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String value, {IconData? icon}) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (value == 'bio') {
          unawaited(_triggerBiometrics());
        } else {
          _onKeyPressed(value);
        }
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.iconBg),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 28, color: colors.textMain)
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: colors.textMain,
                  ),
                ),
        ),
      ),
    );
  }
}
