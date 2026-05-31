import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/app_colors_extension.dart';

/// Єдиний стиль діалогових вікон підтвердження у застосунку.
///
/// Структура: кольорове коло з іконкою → заголовок → пояснення → дві кнопки.
/// Повертає `true`, якщо користувач підтвердив дію, інакше `false`.
class AppDialog {
  const AppDialog._();

  /// Звичайне підтвердження (кнопка дії — акцентного кольору).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    Widget? messageWidget,
    IconData icon = Icons.help_outline_rounded,
    String? confirmText,
    String? cancelText,
    bool barrierDismissible = true,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    return _show(
      context,
      title: title,
      message: message,
      messageWidget: messageWidget,
      icon: icon,
      accentColor: colors?.accent ?? Colors.blue,
      confirmText: confirmText ?? 'confirm'.tr(),
      cancelText: cancelText ?? 'cancel'.tr(),
      barrierDismissible: barrierDismissible,
    );
  }

  /// Небезпечне/незворотне підтвердження (кнопка дії — червона).
  static Future<bool> destructive(
    BuildContext context, {
    required String title,
    String? message,
    Widget? messageWidget,
    IconData icon = Icons.warning_amber_rounded,
    String? confirmText,
    String? cancelText,
    bool barrierDismissible = true,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    return _show(
      context,
      title: title,
      message: message,
      messageWidget: messageWidget,
      icon: icon,
      accentColor: colors?.expense ?? Colors.red,
      confirmText: confirmText ?? 'delete'.tr(),
      cancelText: cancelText ?? 'cancel'.tr(),
      barrierDismissible: barrierDismissible,
    );
  }

  static Future<bool> _show(
    BuildContext context, {
    required String title,
    String? message,
    Widget? messageWidget,
    required IconData icon,
    required Color accentColor,
    required String confirmText,
    required String cancelText,
    required bool barrierDismissible,
  }) async {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    final cardBg = colors?.cardBg ?? Theme.of(context).cardColor;
    final textMain =
        colors?.textMain ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = colors?.textSecondary ?? Colors.grey;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
                textAlign: TextAlign.center,
              ),
              if (messageWidget != null) ...[
                const SizedBox(height: 12),
                DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 14, color: textSecondary),
                  textAlign: TextAlign.center,
                  child: messageWidget,
                ),
              ] else if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(fontSize: 14, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
