import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../../theme/app_colors_extension.dart';
import '../../theme/category_defaults.dart';
import '../../providers/all_providers.dart';

class CustomNumpad extends ConsumerStatefulWidget {
  final Function(String) onKeyPressed;

  const CustomNumpad({super.key, required this.onKeyPressed});

  @override
  ConsumerState<CustomNumpad> createState() => _CustomNumpadState();
}

class _CustomNumpadState extends ConsumerState<CustomNumpad> {
  bool? _hasVibrator;

  static const _keys = [
    ['C', '⌫', '%', '÷'],
    ['1', '2', '3', '×'],
    ['4', '5', '6', '-'],
    ['7', '8', '9', '+'],
    ['00', '0', '.', '='],
  ];

  @override
  void initState() {
    super.initState();
    Vibration.hasVibrator().then((v) => _hasVibrator = v);
  }

  void _handleKeyPress(String key) {
    widget.onKeyPressed(key);
    final hapticEnabled =
        ref.read(sharedPreferencesProvider).getBool('haptic_feedback_enabled') ??
        true;
    if (_hasVibrator == true && hapticEnabled) {
      unawaited(Vibration.vibrate(duration: 15, amplitude: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _keys.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _NumpadButton(
                      text: key,
                      isDark: isDark,
                      colors: colors,
                      onPressed: () => _handleKeyPress(key),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NumpadButton extends StatefulWidget {
  final String text;
  final bool isDark;
  final AppColorsExtension colors;
  final VoidCallback onPressed;

  const _NumpadButton({
    required this.text,
    required this.isDark,
    required this.colors,
    required this.onPressed,
  });

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isOperator = ['÷', '×', '-', '+'].contains(widget.text);
    final bool isAction = ['C', '⌫', '%'].contains(widget.text);
    final bool isEqual = widget.text == '=';

    final Color bgColor;
    final Color textColor;

    if (isEqual) {
      bgColor = CategoryDefaults.accountBg;
      textColor = Colors.white;
    } else if (isOperator) {
      bgColor = CategoryDefaults.accountBg.withValues(alpha: 0.15);
      textColor = widget.isDark ? Colors.white : CategoryDefaults.accountBg;
    } else if (isAction) {
      bgColor = widget.colors.iconBg;
      textColor = widget.colors.textSecondary;
    } else {
      bgColor = widget.colors.cardBg;
      textColor = widget.colors.textMain;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _isPressed = true);
        widget.onPressed();
      },
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: Material(
        color: _isPressed
            ? Color.alphaBlend(Colors.black.withValues(alpha: 0.18), bgColor)
            : bgColor,
        elevation: widget.isDark ? 1 : 2,
        shadowColor: widget.isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: (!isOperator && !isAction && !isEqual)
              ? BorderSide(
                  color: widget.colors.textSecondary.withValues(alpha: 0.1),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: widget.text == '⌫'
              ? Icon(Icons.backspace_outlined, color: textColor, size: 20)
              : Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: isOperator || isEqual ? 24 : 20,
                    fontWeight: isOperator || isEqual
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
