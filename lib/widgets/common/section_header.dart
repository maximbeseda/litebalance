import 'package:flutter/material.dart';

import '../../theme/app_colors_extension.dart';

/// Заголовок секції в єдиному стилі: ВЕЛИКИМИ літерами, з розрядкою,
/// приглушеним кольором. Використовується на екранах налаштувань,
/// бекапу, управління даними тощо.
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 14),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors?.textSecondary ?? Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
