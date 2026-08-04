import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/app_colors_extension.dart';

/// Мінімальні дані реальної категорії для демо-анімації перетягування.
class DemoCategory {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String name;

  const DemoCategory({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.name,
  });
}

/// Один крок туру: підсвічуємо ціль за [key] (або показуємо демо по центру,
/// якщо [demo] == true) і пояснюємо текстом.
class _Step {
  final GlobalKey? key;
  final String title;
  final String body;
  final bool circle;
  final bool demo;
  final DemoCategory? demoSource;
  final DemoCategory? demoTarget;

  const _Step({
    required this.title,
    required this.body,
    this.key,
    this.circle = false,
    this.demo = false,
    this.demoSource,
    this.demoTarget,
  });
}

/// Покрокова підказка («coach marks») поверх реального головного екрана —
/// власна реалізація (не пакет), щоб мати повний контроль над стилем:
/// фірмове затемнення, м'яка пульсуюча біла рамка, що чітко обводить контур
/// цілі, та картка в стилі застосунку. Показуємо один раз, при першому вході.
class HomeTutorial {
  HomeTutorial._();

  static const Color _scrim = Color(0xFF0A1026);

  static void start(
    BuildContext context, {
    required GlobalKey incomeKey,
    required GlobalKey accountKey,
    required GlobalKey expenseKey,
    required GlobalKey summaryKey,
    required GlobalKey menuKey,
    required GlobalKey addKey,
    required GlobalKey tileKey,
    DemoCategory? demoSource,
    DemoCategory? demoTarget,
    VoidCallback? onDone,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    final steps = <_Step>[
      _Step(
        key: incomeKey,
        title: 'tutorial_income_title'.tr(),
        body: 'tutorial_income_desc'.tr(),
      ),
      _Step(
        key: accountKey,
        title: 'tutorial_accounts_title'.tr(),
        body: 'tutorial_accounts_desc'.tr(),
      ),
      _Step(
        key: expenseKey,
        title: 'tutorial_expenses_title'.tr(),
        body: 'tutorial_expenses_desc'.tr(),
      ),
      _Step(
        key: summaryKey,
        title: 'tutorial_overview_title'.tr(),
        body: 'tutorial_overview_desc'.tr(),
      ),
      _Step(
        key: menuKey,
        title: 'tutorial_menu_title'.tr(),
        body: 'tutorial_menu_desc'.tr(),
        circle: true,
      ),
      _Step(
        key: addKey,
        title: 'tutorial_add_title'.tr(),
        body: 'tutorial_add_desc'.tr(),
        circle: true,
      ),
      _Step(
        title: 'tutorial_transfer_title'.tr(),
        body: 'tutorial_transfer_desc'.tr(),
        demo: true,
        demoSource: demoSource,
        demoTarget: demoTarget,
      ),
      _Step(
        key: tileKey,
        title: 'tutorial_history_title'.tr(),
        body: 'tutorial_history_desc'.tr(),
        circle: true,
      ),
    ];

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        steps: steps,
        colors: colors,
        scrim: _scrim,
        onClose: () {
          entry.remove();
          onDone?.call();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _CoachOverlay extends StatefulWidget {
  final List<_Step> steps;
  final AppColorsExtension colors;
  final Color scrim;
  final VoidCallback onClose;

  const _CoachOverlay({
    required this.steps,
    required this.colors,
    required this.scrim,
    required this.onClose,
  });

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with TickerProviderStateMixin {
  int _index = 0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void dispose() {
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onClose();
      return;
    }
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() => _index++);
      _fade.forward();
    });
  }

  /// Прямокутник видимої цілі в глобальних координатах (= координати
  /// повноекранного оверлея). null — демо-крок або ціль ще не видно.
  Rect? _targetRect(_Step step) {
    final ctx = step.key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding;

    final base = step.demo ? null : _targetRect(step);
    final bool isLast = _index == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 1. Затемнення з отвором + пульсуюча рамка (отвір рухається разом
          //    із рамкою, тож фон не «прозирає» всередину під час пульсу).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => CustomPaint(
                painter: _ScrimPainter(
                  base: base,
                  circle: step.circle,
                  scrim: widget.scrim,
                  pulse: Curves.easeInOut.transform(_pulse.value),
                ),
              ),
            ),
          ),

          // 2. Поглинач тапів по затемненню.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),

          // 3. Мінімалістичне «Пропустити» — плаваючий напис угорі праворуч.
          if (!isLast)
            Positioned(
              top: safe.top + 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'skip'.tr().toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),

          // 4. Картка з поясненням.
          _positionedCard(
            screen,
            safe,
            base,
            FadeTransition(
              opacity: _fade,
              child: _Card(
                step: step,
                index: _index,
                total: widget.steps.length,
                colors: widget.colors,
                onNext: _next,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedCard(Size screen, EdgeInsets safe, Rect? base, Widget card) {
    final wrapped = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: card,
      ),
    );

    if (base == null) {
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: wrapped,
        ),
      );
    }

    // Ціль у верхній половині — картку знизу; унизу — у верхню (затемнену) зону.
    final placeBelow = base.center.dy < screen.height * 0.5;
    if (placeBelow) {
      return Positioned(
        left: 20,
        right: 20,
        top: base.bottom + 26,
        child: wrapped,
      );
    }
    return Positioned(
      left: 20,
      right: 20,
      top: safe.top + 54,
      child: wrapped,
    );
  }
}

/// Малює затемнення з «діркою» під ціллю та м'яку пульсуючу білу рамку.
/// Отвір і рамка — це один і той самий прямокутник, тож при пульсі між блоком
/// і рамкою ніколи не проступає тло.
class _ScrimPainter extends CustomPainter {
  final Rect? base;
  final bool circle;
  final Color scrim;
  final double pulse; // 0..1

  _ScrimPainter({
    required this.base,
    required this.circle,
    required this.scrim,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrimPaint = Paint()..color = scrim.withValues(alpha: 0.90);

    if (base == null) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    // Рамка трохи більша за блок і «дихає» на кілька пікселів.
    final pad = (circle ? 5.0 : 6.0) + 2.0 * pulse;
    final r = base!.inflate(pad);
    final rr = RRect.fromRectAndRadius(
      r,
      Radius.circular(circle ? r.shortestSide / 2 : 26),
    );

    // Отвір збігається з рамкою → тло не проступає всередину.
    final path = Path()
      ..addRect(full)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, scrimPaint);

    // М'яке зовнішнє світіння.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.05 + 0.07 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Основна тонка біла рамка.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.6 + 0.3 * pulse),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.base != base || old.pulse != pulse || old.circle != circle;
}

class _Card extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;
  final AppColorsExtension colors;
  final VoidCallback onNext;

  const _Card({
    required this.step,
    required this.index,
    required this.total,
    required this.colors,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLast = index == total - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step.demo) ...[
          _TransferDemo(source: step.demoSource, target: step.demoTarget),
          const SizedBox(height: 22),
        ],
        Row(
          children: List.generate(total, (i) {
            final active = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 6),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? colors.accent
                    : Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          step.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          step.body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerRight,
          child: _NextButton(
            label: (isLast ? 'done' : 'tutorial_next').tr(),
            isLast: isLast,
            accent: colors.accent,
            onTap: onNext,
          ),
        ),
      ],
    );
  }
}

/// Кнопка «Далі/Готово» в стилі застосунку: акцентна пігулка з тінню-німбом.
class _NextButton extends StatelessWidget {
  final String label;
  final bool isLast;
  final Color accent;
  final VoidCallback onTap;

  const _NextButton({
    required this.label,
    required this.isLast,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      elevation: 0,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Зациклена демка головного жесту на РЕАЛЬНИХ категоріях користувача: монетка
/// категорії-джерела (рахунок) перелітає дугою на категорію-ціль (витрату) —
/// «перетягніть, щоб створити транзакцію». Якщо категорій немає — запасні іконки.
class _TransferDemo extends StatefulWidget {
  final DemoCategory? source;
  final DemoCategory? target;

  const _TransferDemo({this.source, this.target});

  @override
  State<_TransferDemo> createState() => _TransferDemoState();
}

class _TransferDemoState extends State<_TransferDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  DemoCategory get _src =>
      widget.source ??
      const DemoCategory(
        icon: Icons.account_balance_wallet_rounded,
        bg: Color(0x334B6CB7),
        fg: Color(0xFF6E8BD6),
        name: 'Account',
      );

  DemoCategory get _tgt =>
      widget.target ??
      const DemoCategory(
        icon: Icons.shopping_bag_rounded,
        bg: Color(0x33E06C75),
        fg: Color(0xFFE06C75),
        name: 'Expense',
      );

  @override
  Widget build(BuildContext context) {
    const double h = 128;
    const double node = 60;
    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          const leftCenter = Offset(node / 2 + 6, 42);
          final rightCenter = Offset(width - node / 2 - 6, 42);

          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final flight = (v / 0.66).clamp(0.0, 1.0);
              final t = Curves.easeInOut.transform(flight);

              final pos = Offset.lerp(leftCenter, rightCenter, t)!;
              final arc = -30 * math.sin(t * math.pi);
              final coinCenter = Offset(pos.dx, pos.dy + arc);

              final coinOpacity = flight < 0.06
                  ? flight / 0.06
                  : (flight > 0.9 ? (1 - (flight - 0.9) / 0.1) : 1.0);
              final landPulse = flight > 0.9
                  ? Curves.easeOut.transform((flight - 0.9) / 0.1)
                  : 0.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _node(leftCenter, node, _src, 1),
                  _node(rightCenter, node, _tgt, 1 + 0.12 * landPulse),
                  // Летюча монетка (виглядає як монетка джерела).
                  Positioned(
                    left: coinCenter.dx - 17,
                    top: coinCenter.dy - 17,
                    child: Opacity(
                      opacity: coinOpacity.clamp(0.0, 1.0),
                      child: _coin(_src, 34),
                    ),
                  ),
                  Positioned(
                    left: coinCenter.dx + 6,
                    top: coinCenter.dy + 12,
                    child: Opacity(
                      opacity: coinOpacity.clamp(0.0, 1.0) * 0.9,
                      child: const Icon(
                        Icons.touch_app_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _node(Offset center, double size, DemoCategory cat, double scale) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(scale: scale, child: _coin(cat, size)),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 24,
            child: Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coin(DemoCategory cat, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cat.bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(cat.icon, size: size * 0.44, color: cat.fg),
    );
  }
}
