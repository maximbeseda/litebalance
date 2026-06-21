import 'package:flutter/material.dart';

/// Єдиний стиль відображення «сума + значок валюти» по всьому додатку:
/// значок трохи менший і трохи світліший за суму, вирівняний по нижньому краю.
///
/// Нижнє вирівнювання досягається baseline'ом: цифри не мають нижніх виносних
/// елементів, тож їхній baseline збігається з нижнім краєм — а менший значок на
/// тому ж baseline «сідає» рівно по низу суми.
class CurrencyAmount {
  CurrencyAmount._();

  /// Наскільки значок менший за суму.
  static const double _symbolSizeFactor = 0.8;

  /// Наскільки значок світліший (множник до альфи кольору суми).
  /// 0.6 — щоб збігалося з еталоном у summary_header (баланс зверху).
  static const double _symbolAlphaFactor = 0.6;

  /// Стиль значка, похідний від стилю суми.
  static TextStyle symbolStyle(TextStyle base) {
    final double size = base.fontSize ?? 14.0;
    final Color color = base.color ?? const Color(0xFF000000);
    return base.copyWith(
      fontSize: size * _symbolSizeFactor,
      color: color.withValues(alpha: color.a * _symbolAlphaFactor),
    );
  }

  /// Інлайн-спани «сума + значок» — для вставки в наявні RichText/Text.rich.
  static List<InlineSpan> spans(
    String amount,
    String symbol,
    TextStyle base,
  ) {
    return [
      TextSpan(text: amount, style: base),
      TextSpan(text: ' ${symbol.trim()}', style: symbolStyle(base)),
    ];
  }
}

/// Drop-in заміна для `Text('$amount $symbol', style: ...)`, де значок
/// рендериться меншим/світлішим і вирівняним по нижньому краю суми.
class AmountText extends StatelessWidget {
  final String amount;
  final String symbol;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AmountText({
    super.key,
    required this.amount,
    required this.symbol,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: CurrencyAmount.spans(amount, symbol, style)),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
