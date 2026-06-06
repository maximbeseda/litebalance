import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors_extension.dart';

/// Уніфікований «порожній стан» для всіх екранів та шторок.
///
/// Малює кольорову векторну ілюстрацію (без зовнішніх асетів) з іконкою,
/// заголовком, підзаголовком та опційною кнопкою-дією. Анімація появи —
/// одноразова (fade + scale), не навантажує кадр у спокої.
class AppEmptyState extends StatelessWidget {
  /// Головна іконка-гліф у центрі ілюстрації.
  final IconData icon;

  /// Базовий колір ілюстрації. Якщо null — береться `accent` з теми.
  final Color? color;

  final String title;
  final String? subtitle;

  /// Опційна кнопка під текстом (наприклад, «Додати»).
  final Widget? action;

  /// Чи вмикати анімацію появи.
  final bool animate;

  /// Розмір векторної ілюстрації (для тісних місць можна зменшити).
  final double illustrationSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.subtitle,
    this.action,
    this.animate = true,
    this.illustrationSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    final baseColor = color ?? colors?.accent ?? Theme.of(context).primaryColor;
    final textMain =
        colors?.textMain ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = colors?.textSecondary ?? Colors.grey;

    Widget illustration = EmptyIllustration(
      icon: icon,
      color: baseColor,
      size: illustrationSize,
    );
    if (animate) {
      illustration = illustration
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            duration: 450.ms,
            curve: Curves.easeOutBack,
          );
    }

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        illustration,
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: textSecondary,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 24),
          action!,
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: content,
      ),
    );
  }
}

/// Кольорова векторна ілюстрація: м'яке коло-«блоб», тонке кільце,
/// декоративні крапки та центральний гліф. Малюється у фірмовому відтінку.
class EmptyIllustration extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const EmptyIllustration({
    super.key,
    required this.icon,
    required this.color,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmptyArtPainter(color: color),
        child: Center(
          child: Icon(icon, size: size * 0.34, color: color),
        ),
      ),
    );
  }
}

class _EmptyArtPainter extends CustomPainter {
  final Color color;

  _EmptyArtPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 1. М'яке заповнене коло (фон-блоб).
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.92));
    canvas.drawCircle(center, r * 0.92, blobPaint);

    // 2. Тонке кільце.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.22);
    canvas.drawCircle(center, r * 0.7, ringPaint);

    // 3. Декоративні крапки по колу.
    final dotPaint = Paint()..style = PaintingStyle.fill;
    const dots = [
      (-0.35, 0.30, 0.5, 5.0),
      (0.95, -0.15, 0.35, 7.0),
      (0.55, 0.85, 0.25, 4.0),
      (-0.85, -0.45, 0.30, 6.0),
    ];
    for (final (angleFrac, _, alpha, radius) in dots) {
      final angle = angleFrac * 2 * math.pi;
      final dist = r * 0.82;
      final p = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      dotPaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(p, radius, dotPaint);
    }

    // 4. Внутрішнє світліше коло під гліфом.
    final innerPaint = Paint()..color = color.withValues(alpha: 0.12);
    canvas.drawCircle(center, r * 0.42, innerPaint);
  }

  @override
  bool shouldRepaint(_EmptyArtPainter oldDelegate) =>
      oldDelegate.color != color;
}
