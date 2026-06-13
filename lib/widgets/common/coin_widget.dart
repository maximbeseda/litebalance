import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import '../../database/app_database.dart';
import '../../models/app_currency.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/icon_helper.dart';

class CoinWidget extends StatefulWidget {
  final Category category;
  final bool isFeedback;
  final bool isHovered;
  final bool enableHero;
  final Widget Function(Widget normalCoin, Widget placeholderCoin)? coinWrapper;

  const CoinWidget({
    super.key,
    required this.category,
    this.isFeedback = false,
    this.isHovered = false,
    this.enableHero = true,
    this.coinWrapper,
  });

  @override
  State<CoinWidget> createState() => _CoinWidgetState();
}

class _CoinWidgetState extends State<CoinWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final Color catBgColor = Color(widget.category.bgColor);
    final Color catIconColor = Color(widget.category.iconColor);
    final IconData catIconData = IconHelper.getIcon(widget.category.icon);

    final String displayAmount = CurrencyFormatter.format(
      widget.category.amount,
      currencyCode: widget.category.currency,
    );
    final String currencySymbol = AppCurrency.fromCode(
      widget.category.currency,
    ).symbol;

    final bool isIncome = widget.category.type == CategoryType.income;
    final bool isExpense = widget.category.type == CategoryType.expense;

    double progress = 0.0;
    Color ringColor = Colors.blueAccent;
    final bool hasBudget =
        widget.category.budget != null && widget.category.budget! > 0;

    if (hasBudget) {
      final double amountAbs = widget.category.amount.abs().toDouble();
      progress = (amountAbs / widget.category.budget!.toDouble()).clamp(
        0.0,
        1.0,
      );

      if (isIncome) {
        ringColor = progress >= 1.0 ? colors.income : Colors.blueAccent;
      } else if (isExpense) {
        final DateTime now = DateTime.now();
        final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final int currentDay = now.day;

        final double expectedPace =
            (widget.category.budget!.toDouble() / daysInMonth) * currentDay;

        if (amountAbs >= widget.category.budget!.toDouble()) {
          ringColor = colors.expense;
        } else if (amountAbs > expectedPace) {
          ringColor = Colors.orange;
        } else {
          ringColor = Colors.blueAccent;
        }
      }
    }

    final Color shadowColor = colors.textMain.withValues(alpha: 0.1);

    final Widget innerCoin = Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: catBgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(catIconData, color: catIconColor, size: 24),
          if (hasBudget)
            Positioned(
              bottom: 6,
              child: Text(
                CurrencyFormatter.formatBudget(widget.category.budget!),
                style: TextStyle(
                  fontSize: 8,
                  color: catIconColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );

    final Widget basicCoin = widget.enableHero
        ? Hero(
            tag: 'category_coin_${widget.category.id}',
            flightShuttleBuilder:
                (
                  flightContext,
                  animation,
                  flightDirection,
                  fromHeroContext,
                  toHeroContext,
                ) {
                  return Material(
                    type: MaterialType.transparency,
                    child: toHeroContext.widget,
                  );
                },
            child: Material(type: MaterialType.transparency, child: innerCoin),
          )
        : innerCoin;

    final Widget placeholderCoin = Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(color: colors.iconBg, shape: BoxShape.circle),
      child: Icon(
        catIconData,
        color: colors.textSecondary.withValues(alpha: 0.3),
        size: 24,
      ),
    );

    if (widget.isFeedback) {
      return basicCoin;
    }

    final Widget interactiveCoin = widget.coinWrapper != null
        ? widget.coinWrapper!(basicCoin, placeholderCoin)
        : basicCoin;

    final Widget coinWithBudget = SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasBudget)
            SizedBox(
              width: 62,
              height: 62,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: colors.textMain.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
            ),
          interactiveCoin,
        ],
      ),
    );

    // 👇 ВИПРАВЛЕНО: Додано перевірку if (mounted)
    final Widget scaledCoin = Listener(
      onPointerDown: (_) {
        if (mounted) setState(() => _isPressed = true);
      },
      onPointerUp: (_) {
        if (mounted) setState(() => _isPressed = false);
      },
      onPointerCancel: (_) {
        if (mounted) setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : (widget.isHovered ? 1.15 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: coinWithBudget,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 14,
          child: Text(
            widget.category.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        scaledCoin,
        const SizedBox(height: 2),
        SizedBox(
          width: 75,
          height: 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Text(
                '$displayAmount $currencySymbol',
                key: ValueKey<String>('$displayAmount $currencySymbol'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textMain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
