import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Фірмова марка LiteBalance: темно-синій круг із монограмом «Lb»
/// (Quicksand, біла «L» + синя «B» з делікатним потовщенням). [halo] додає
/// навколо круга наше сяйво — концентричні кільця з орбітальними «планетами»
/// у тому ж темно-синьому кольорі (айдентика, зав'язана на колах).
class AppLogo extends StatelessWidget {
  final double size;
  final bool halo;

  const AppLogo({super.key, this.size = 120, this.halo = false});

  static const Color tileTop = Color(0xFF0F1830);
  static const Color tileBottom = Color(0xFF05070E);
  static const Color haloColor = Color(0xFF2950A0);
  static const Color bColor = Color(0xFF4F74C8);
  static const String fontFamily = 'Quicksand';

  @override
  Widget build(BuildContext context) {
    final double coin = halo ? size * 0.6 : size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (halo)
            Positioned.fill(
              child: CustomPaint(painter: _HaloPainter(haloColor)),
            ),
          Container(
            width: coin,
            height: coin,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tileTop, tileBottom],
              ),
              boxShadow: [
                BoxShadow(
                  color: haloColor.withValues(alpha: 0.28),
                  blurRadius: coin * 0.16,
                  offset: Offset(0, coin * 0.05),
                ),
              ],
            ),
            alignment: Alignment.center,
            // Менший за коло — у круглій формі краї «з'їдають» простір,
            // тож монограм помітно менший, ніж у квадратній іконці.
            child: AppMonogram(size: coin * 0.72),
          ),
        ],
      ),
    );
  }
}

/// Декоративне сяйво навколо лого: концентричні кільця + «планети» на орбітах.
class _HaloPainter extends CustomPainter {
  final Color color;

  _HaloPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // М'який блоб-ореол.
    final blob = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, blob);

    // Концентричні кільця.
    final ring = Paint()..style = PaintingStyle.stroke;
    ring
      ..strokeWidth = r * 0.045
      ..color = color.withValues(alpha: 0.32);
    canvas.drawCircle(center, r * 0.72, ring);
    ring
      ..strokeWidth = r * 0.035
      ..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(center, r * 0.93, ring);

    // «Планети» на орбітах.
    final dot = Paint()..style = PaintingStyle.fill;
    void orbitDot(double ringR, double angleDeg, double dotR, double alpha) {
      final a = angleDeg * math.pi / 180;
      dot.color = color.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(center.dx + math.cos(a) * ringR, center.dy + math.sin(a) * ringR),
        dotR,
        dot,
      );
    }

    orbitDot(r * 0.72, -55, r * 0.07, 0.55);
    orbitDot(r * 0.93, 135, r * 0.055, 0.40);
    orbitDot(r * 0.93, 25, r * 0.04, 0.28);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.color != color;
}

/// Монограм «Lb» без круга — для adaptive-іконки чи окремих місць.
/// [size] — опорний розмір (зазвичай діаметр круга).
class AppMonogram extends StatelessWidget {
  final double size;

  const AppMonogram({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final lSize = size * 0.62;
    final bSize = size * 0.47;
    final sw = size * 0.016;

    TextSpan span({required bool stroke}) {
      TextStyle styleFor(double fontSize, Color color) => stroke
          ? TextStyle(
              fontSize: fontSize,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..strokeJoin = StrokeJoin.round
                ..color = color,
            )
          : TextStyle(fontSize: fontSize, color: color);

      return TextSpan(
        style: const TextStyle(
          fontFamily: AppLogo.fontFamily,
          fontVariations: [FontVariation('wght', 700)],
          height: 1.0,
        ),
        children: [
          TextSpan(
            text: 'L',
            style: styleFor(
              lSize,
              Colors.white,
            ).copyWith(letterSpacing: size * 0.008),
          ),
          TextSpan(text: 'B', style: styleFor(bSize, AppLogo.bColor)),
        ],
      );
    }

    // Два проходи: обведення (faux-bold) під заливкою.
    return Stack(
      alignment: Alignment.center,
      children: [
        Text.rich(span(stroke: true)),
        Text.rich(span(stroke: false)),
      ],
    );
  }
}
