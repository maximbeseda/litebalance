import 'package:flutter/material.dart';

import '../../theme/app_colors_extension.dart';

/// Єдиний стиль снекбарів у застосунку.
///
/// Замість того щоб щоразу будувати власний [SnackBar] з рамкою, іконкою та
/// відступами, виклич [AppSnackbar.success] / [AppSnackbar.error] /
/// [AppSnackbar.info] / [AppSnackbar.warning].
enum _SnackKind { success, error, info, warning }

class AppSnackbar {
  const AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackKind.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackKind.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _SnackKind.info);

  static void warning(BuildContext context, String message) =>
      _show(context, message, _SnackKind.warning);

  static void _show(BuildContext context, String message, _SnackKind kind) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    final Color accentColor;
    final IconData icon;
    switch (kind) {
      case _SnackKind.success:
        accentColor = colors?.income ?? Colors.green;
        icon = Icons.check_circle_outline;
      case _SnackKind.error:
        accentColor = colors?.expense ?? Colors.red;
        icon = Icons.error_outline;
      case _SnackKind.warning:
        accentColor = colors?.warning ?? Colors.amber;
        icon = Icons.warning_amber_rounded;
      case _SnackKind.info:
        accentColor = colors?.accent ?? Colors.blue;
        icon = Icons.info_outline;
    }

    final cardBg = colors?.cardBg ?? Theme.of(context).cardColor;
    final textMain =
        colors?.textMain ?? Theme.of(context).colorScheme.onSurface;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardBg,
        elevation: 4,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accentColor, width: 1.0),
        ),
        content: Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textMain,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
