import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// Один крок туру.
class _Step {
  final GlobalKey? key; // ціль (звичайний крок)
  final String title;
  final String body;
  final bool circle;
  final double insetH; // горизонтальний підріз для широких цілей (шапка)

  // Демо-крок «як створити транзакцію»:
  final bool demo;
  final GlobalKey? sourceKey; // реальна монетка-джерело на екрані
  final GlobalKey? targetKey; // реальна монетка-ціль на екрані
  final DemoCategory? demoSource;
  final DemoCategory? demoTarget;

  const _Step({
    required this.title,
    required this.body,
    this.key,
    this.circle = false,
    this.insetH = 0,
    this.demo = false,
    this.sourceKey,
    this.targetKey,
    this.demoSource,
    this.demoTarget,
  });
}

class _HoleSpec {
  final Rect rect;
  final bool circle;
  const _HoleSpec(this.rect, this.circle);
}

/// Покрокова підказка («coach marks») поверх реального головного екрана —
/// власна реалізація з фірмовим стилем: затемнення, м'яка пульсуюча біла рамка
/// точно по контуру цілі, а демо транзакції програється прямо на екрані між
/// реальними монетками користувача. Показуємо один раз, при першому вході.
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
    required GlobalKey demoSourceKey,
    required GlobalKey demoTargetKey,
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
        insetH: 14, // шапка на всю ширину — підрізаємо, щоб було видно грані
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
        sourceKey: demoSourceKey,
        targetKey: demoTargetKey,
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

  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void dispose() {
    _pulse.dispose();
    _flight.dispose();
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

  Rect? _rectFor(GlobalKey? key, {double insetH = 0}) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    var r = box.localToGlobal(Offset.zero) & box.size;
    if (insetH > 0) {
      r = Rect.fromLTRB(r.left + insetH, r.top, r.right - insetH, r.bottom);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding;
    final bool isLast = _index == widget.steps.length - 1;

    // Визначаємо отвори та (для демо) координати монеток на екрані.
    List<_HoleSpec> holes = [];
    Rect? srcRect, tgtRect;
    bool demoOnScreen = false;

    if (step.demo) {
      srcRect = _rectFor(step.sourceKey);
      tgtRect = _rectFor(step.targetKey);
      if (srcRect != null && tgtRect != null) {
        demoOnScreen = true;
        holes = [_HoleSpec(srcRect, true), _HoleSpec(tgtRect, true)];
      }
    } else {
      final r = _rectFor(step.key, insetH: step.insetH);
      if (r != null) holes = [_HoleSpec(r, step.circle)];
    }

    // Демо в картці лише як запасний варіант, коли реальних монеток немає.
    final bool inlineDemo = step.demo && !demoOnScreen;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Затемнення + пульсуючі рамки (отвір рухається разом із рамкою).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => CustomPaint(
                painter: _ScrimPainter(
                  holes: holes,
                  scrim: widget.scrim,
                  pulse: Curves.easeInOut.transform(_pulse.value),
                ),
              ),
            ),
          ),

          // Поглинач тапів.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),

          // Демо просто на екрані: монетка джерела дугою летить у ціль.
          if (demoOnScreen)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flight,
                  builder: (_, _) => CustomPaint(
                    painter: _FlyingCoinPainter(
                      from: srcRect!.center,
                      to: tgtRect!.center,
                      t: _flight.value,
                      cat:
                          step.demoSource ??
                          const DemoCategory(
                            icon: Icons.account_balance_wallet_rounded,
                            bg: Color(0xFF4B6CB7),
                            fg: Colors.white,
                            name: '',
                          ),
                    ),
                  ),
                ),
              ),
            ),

          // «Пропустити» — унизу екрана.
          if (!isLast)
            Positioned(
              left: 0,
              right: 0,
              bottom: safe.bottom + 18,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
            ),

          // Картка з поясненням.
          _positionedCard(
            screen,
            safe,
            holes,
            step.demo,
            demoOnScreen,
            FadeTransition(
              opacity: _fade,
              child: _Card(
                step: step,
                index: _index,
                total: widget.steps.length,
                colors: widget.colors,
                inlineDemo: inlineDemo,
                onNext: _next,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedCard(
    Size screen,
    EdgeInsets safe,
    List<_HoleSpec> holes,
    bool demo,
    bool demoOnScreen,
    Widget card,
  ) {
    final wrapped = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: card,
      ),
    );

    // Демо на екрані — картку вгору (шлях монетки в центрі/низу).
    if (demoOnScreen) {
      return Positioned(left: 20, right: 20, top: safe.top + 16, child: wrapped);
    }

    // Запасне демо в картці або відсутня ціль — по центру.
    if (holes.isEmpty) {
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: wrapped,
        ),
      );
    }

    final hole = holes.first.rect;
    final placeBelow = hole.center.dy < screen.height * 0.5;
    if (placeBelow) {
      return Positioned(
        left: 20,
        right: 20,
        top: hole.bottom + 26,
        child: wrapped,
      );
    }
    return Positioned(left: 20, right: 20, top: safe.top + 16, child: wrapped);
  }
}

/// Затемнення з отворами під цілями + м'яка пульсуюча біла рамка. Отвір і рамка
/// — один прямокутник, тож при пульсі тло не проступає всередину.
class _ScrimPainter extends CustomPainter {
  final List<_HoleSpec> holes;
  final Color scrim;
  final double pulse; // 0..1

  _ScrimPainter({
    required this.holes,
    required this.scrim,
    required this.pulse,
  });

  RRect _rr(_HoleSpec h, double grow) {
    final r = h.rect.inflate((h.circle ? 5.0 : 6.0) + grow);
    return RRect.fromRectAndRadius(
      r,
      Radius.circular(h.circle ? r.shortestSide / 2 : 26),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrimPaint = Paint()..color = scrim.withValues(alpha: 0.90);
    final grow = 2.0 * pulse;

    if (holes.isEmpty) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    final cut = Path()..addRect(full);
    for (final h in holes) {
      cut.addRRect(_rr(h, grow));
    }
    cut.fillType = PathFillType.evenOdd;
    canvas.drawPath(cut, scrimPaint);

    for (final h in holes) {
      final rr = _rr(h, grow);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white.withValues(alpha: 0.05 + 0.07 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.6 + 0.3 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.pulse != pulse || old.holes != holes;
}

/// Малює монетку, що дугою летить від [from] до [to] (зациклено), плюс палець.
class _FlyingCoinPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double t; // 0..1
  final DemoCategory cat;

  _FlyingCoinPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.cat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final flight = (t / 0.72).clamp(0.0, 1.0);
    final e = Curves.easeInOut.transform(flight);
    final pos = Offset.lerp(from, to, e)!;
    final arc = -34 * math.sin(e * math.pi);
    final c = Offset(pos.dx, pos.dy + arc);

    final opacity = flight < 0.06
        ? flight / 0.06
        : (flight > 0.9 ? (1 - (flight - 0.9) / 0.1) : 1.0);
    if (opacity <= 0) return;

    const double radius = 21;

    // Тінь.
    canvas.drawCircle(
      c.translate(0, 3),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Тіло монетки — у кольорі категорії-джерела.
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = cat.bg.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.7 * opacity),
    );

    // Іконка категорії всередині.
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(cat.icon.codePoint),
        style: TextStyle(
          fontSize: radius,
          fontFamily: cat.icon.fontFamily,
          package: cat.icon.fontPackage,
          color: cat.fg.withValues(alpha: opacity),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

    // Палець-вказівник трохи нижче-праворуч.
    final finger = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app_rounded.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: Icons.touch_app_rounded.fontFamily,
          package: Icons.touch_app_rounded.fontPackage,
          color: Colors.white.withValues(alpha: 0.9 * opacity),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    finger.paint(canvas, c + const Offset(6, 8));
  }

  @override
  bool shouldRepaint(_FlyingCoinPainter old) =>
      old.t != t || old.from != from || old.to != to;
}

class _Card extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;
  final AppColorsExtension colors;
  final bool inlineDemo;
  final VoidCallback onNext;

  const _Card({
    required this.step,
    required this.index,
    required this.total,
    required this.colors,
    required this.inlineDemo,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLast = index == total - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inlineDemo) ...[
          _InlineTransferDemo(
            source: step.demoSource,
            target: step.demoTarget,
          ),
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

/// Запасна демка в картці (коли на екрані немає монеток): дві категорії-кола й
/// монетка, що перелітає між ними. Використовує реальні або дефолтні категорії.
class _InlineTransferDemo extends StatefulWidget {
  final DemoCategory? source;
  final DemoCategory? target;

  const _InlineTransferDemo({this.source, this.target});

  @override
  State<_InlineTransferDemo> createState() => _InlineTransferDemoState();
}

class _InlineTransferDemoState extends State<_InlineTransferDemo>
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
              final flight = (_c.value / 0.66).clamp(0.0, 1.0);
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
                  Positioned(
                    left: coinCenter.dx - 17,
                    top: coinCenter.dy - 17,
                    child: Opacity(
                      opacity: coinOpacity.clamp(0.0, 1.0),
                      child: _coin(_src, 34),
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
