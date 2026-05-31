import 'package:flutter/material.dart';

import '../../theme/app_colors_extension.dart';

/// Кольоровий значок-«плитка» з іконкою в єдиному стилі.
///
/// Заокруглений квадрат із напівпрозорим тлом заданого відтінку та іконкою
/// того ж відтінку. Використовується в боковому меню, рядках налаштувань тощо,
/// щоб іконки були кольоровими, але в одній гамі.
class AppIconBadge extends StatelessWidget {
  final IconData icon;

  /// Відтінок значка. Якщо null — береться `accent` з теми.
  final Color? color;

  /// Розмір плитки.
  final double size;

  /// Радіус заокруглення кутів.
  final double radius;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    final c = color ?? colors?.accent ?? Theme.of(context).primaryColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: c, size: size * 0.55),
    );
  }
}
