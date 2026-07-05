import 'package:flutter/material.dart';

/// Акуратна овальна плашка фіксованого розміру з коротким позначенням
/// (код валюти, код мови тощо). Тло — напівпрозорий відтінок [color],
/// текст — того ж відтінку. Довгий вміст масштабується, щоб усі плашки
/// в списку були однакового розміру і по ширині, і по висоті.
class AppPill extends StatelessWidget {
  final String text;
  final Color color;
  final double width;
  final double height;

  const AppPill({
    super.key,
    required this.text,
    required this.color,
    this.width = 64,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
