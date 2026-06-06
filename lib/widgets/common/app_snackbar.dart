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

    final Color bgColor;
    final IconData icon;
    switch (kind) {
      case _SnackKind.success:
        bgColor = colors?.income ?? Colors.green;
        icon = Icons.check_circle_outline;
      case _SnackKind.error:
        bgColor = colors?.expense ?? Colors.red;
        icon = Icons.error_outline;
      case _SnackKind.warning:
        bgColor = colors?.warning ?? Colors.amber;
        icon = Icons.warning_amber_rounded;
      case _SnackKind.info:
        bgColor = colors?.accent ?? Colors.blue;
        icon = Icons.info_outline;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        // Суцільна кольорова смуга на всю ширину, що виїжджає знизу екрана.
        behavior: SnackBarBehavior.fixed,
        backgroundColor: bgColor,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
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
