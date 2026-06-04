import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Маленький «ілюстрований бейдж» категорії: декоративне векторне сяйво
/// (м'який блоб + ледь помітні крапки в кольорі категорії) позаду суцільної
/// монетки з іконкою. Декор у стилі порожніх станів, але іконка завжди чітка
/// (вона на кольоровому колі, а не на тлі картки), тож працює для будь-яких
/// кольорів і тем. Усі елементи пропорційні до [size].
class CategoryHaloIcon extends StatelessWidget {
  final IconData icon;

  /// Колір-«заливка» монетки (фон категорії).
  final Color bgColor;

  /// Колір іконки на монетці.
  final Color iconColor;

  /// Загальний розмір бейджа (з декоративним сяйвом).
  final double size;

  const CategoryHaloIcon({
    super.key,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    this.size = 52,
  });

  // Дуже світлі кольори (напр. сірий фон витрат) погано видно як сяйво —
  // підсилюємо їх через HSL, щоб кільця завжди читалися.
  Color get _haloColor {
    final hsl = HSLColor.fromColor(bgColor);
    if (hsl.lightness > 0.7) {
      return hsl
          .withLightness(0.6)
          .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
          .toColor();
    }
    return bgColor;
  }

  @override
  Widget build(BuildContext context) {
    final double coin = size * 0.6;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HaloPainter(color: _haloColor),
        child: Center(
          child: Container(
            width: coin,
            height: coin,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.35),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: coin * 0.52),
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final Color color;

  _HaloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // М'який блоб-ореол.
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, blobPaint);

    // Концентричні кільця-«хвилі» навколо монетки (пропорційні до розміру).
    final ringPaint = Paint()..style = PaintingStyle.stroke;

    ringPaint
      ..strokeWidth = r * 0.05
      ..color = color.withValues(alpha: 0.32);
    canvas.drawCircle(center, r * 0.72, ringPaint);

    ringPaint
      ..strokeWidth = r * 0.04
      ..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(center, r * 0.93, ringPaint);

    // «Планети на орбітах» — крапки, що сидять точно на кільцях.
    final dotPaint = Paint()..style = PaintingStyle.fill;
    void orbitDot(double ringR, double angleDeg, double dotR, double alpha) {
      final a = angleDeg * math.pi / 180;
      final p = Offset(
        center.dx + math.cos(a) * ringR,
        center.dy + math.sin(a) * ringR,
      );
      dotPaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(p, dotR, dotPaint);
    }

    orbitDot(r * 0.72, -55, r * 0.07, 0.55);
    orbitDot(r * 0.93, 135, r * 0.055, 0.40);
    orbitDot(r * 0.93, 25, r * 0.04, 0.28);
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) => oldDelegate.color != color;
}
