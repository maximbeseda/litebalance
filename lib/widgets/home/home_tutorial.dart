import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/app_colors_extension.dart';

/// Один крок туру: підсвічуємо ціль за [key] (або показуємо демо по центру,
/// якщо [key] == null) і пояснюємо текстом.
class _Step {
  final GlobalKey? key;
  final String title;
  final String body;
  final bool circle;

  /// Показати анімацію-демку транзакції в картці (для кроку «як створити
  /// транзакцію»). Такий крок не має цілі й показується по центру.
  final bool demo;

  const _Step({
    required this.title,
    required this.body,
    this.key,
    this.circle = false,
    this.demo = false,
  });
}

/// Покрокова підказка («coach marks») поверх реального головного екрана —
/// власна реалізація (не пакет), щоб мати повний контроль над стилем:
/// фірмове затемнення, м'яка пульсуюча біла рамка навколо фокуса та картка
/// в стилі застосунку. Показуємо один раз, при першому вході на головний.
class HomeTutorial {
  HomeTutorial._();

  static const Color _scrim = Color(0xFF0A1026);

  /// Запускає тур поверх поточного екрана.
  static void start(
    BuildContext context, {
    required GlobalKey incomeKey,
    required GlobalKey accountKey,
    required GlobalKey expenseKey,
    required GlobalKey summaryKey,
    required GlobalKey menuKey,
    required GlobalKey addKey,
    required GlobalKey tileKey,
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
    duration: const Duration(milliseconds: 1300),
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

  /// Прямокутник цілі поточного кроку в глобальних координатах (= координати
  /// повноекранного оверлея). null — якщо цілі немає (демо) або її ще не видно.
  Rect? _targetRect(_Step step) {
    final ctx = step.key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding;

    final rawRect = step.demo ? null : _targetRect(step);
    // Невеликий відступ навколо цілі, щоб рамка «дихала».
    final hole = rawRect?.inflate(step.circle ? 8 : 10);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 1. Затемнення з отвором + пульсуюча рамка.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => CustomPaint(
                painter: _ScrimPainter(
                  hole: hole,
                  circle: step.circle,
                  scrim: widget.scrim,
                  pulse: Curves.easeInOut.transform(_pulse.value),
                ),
              ),
            ),
          ),

          // 2. Поглинач тапів по затемненню (щоб не «протикати» в застосунок).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),

          // 3. Картка з поясненням.
          _positionedCard(
            screen,
            safe,
            hole,
            FadeTransition(
              opacity: _fade,
              child: _Card(
                step: step,
                index: _index,
                total: widget.steps.length,
                colors: widget.colors,
                onNext: _next,
                onSkip: widget.onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedCard(Size screen, EdgeInsets safe, Rect? hole, Widget card) {
    final wrapped = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: card,
      ),
    );

    if (hole == null) {
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: wrapped,
        ),
      );
    }

    // Ціль у верхній половині — картку знизу; ціль унизу — картку у верхню
    // (затемнену) зону, щоб не перекривати фокус.
    final placeBelow = hole.center.dy < screen.height * 0.5;
    if (placeBelow) {
      return Positioned(
        left: 20,
        right: 20,
        top: hole.bottom + 20,
        child: wrapped,
      );
    }
    return Positioned(
      left: 20,
      right: 20,
      top: safe.top + 16,
      child: wrapped,
    );
  }
}

/// Малює затемнення з «діркою» під ціллю та м'яку пульсуючу білу рамку.
class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  final bool circle;
  final Color scrim;
  final double pulse; // 0..1

  _ScrimPainter({
    required this.hole,
    required this.circle,
    required this.scrim,
    required this.pulse,
  });

  RRect _rr(Rect r) => RRect.fromRectAndRadius(
    r,
    Radius.circular(circle ? r.shortestSide / 2 : 22),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrimPaint = Paint()..color = scrim.withValues(alpha: 0.90);

    if (hole == null) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    final rr = _rr(hole!);
    final path = Path()
      ..addRect(full)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, scrimPaint);

    // Пульс: рамка трохи «дихає» товщиною, розміром і прозорістю.
    final grow = 1.5 * pulse;
    final rrPulse = _rr(hole!.inflate(grow));

    // М'яке зовнішнє світіння.
    canvas.drawRRect(
      rrPulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.05 + 0.07 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Основна тонка біла рамка.
    canvas.drawRRect(
      rrPulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.55 + 0.35 * pulse),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.pulse != pulse || old.circle != circle;
}

class _Card extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;
  final AppColorsExtension colors;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Card({
    required this.step,
    required this.index,
    required this.total,
    required this.colors,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLast = index == total - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step.demo) ...[
          const _TransferDemo(),
          const SizedBox(height: 20),
        ],
        // Індикатор прогресу.
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
        Row(
          children: [
            if (!isLast)
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'skip'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Spacer(),
            _NextButton(
              label: (isLast ? 'done' : 'tutorial_next').tr(),
              isLast: isLast,
              accent: colors.accent,
              onTap: onNext,
            ),
          ],
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

/// Зациклена демка головного жесту: монетка з лівого кола (рахунок) перелітає
/// дугою в праве коло (витрата) — «перетягніть, щоб створити транзакцію».
class _TransferDemo extends StatefulWidget {
  const _TransferDemo();

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

  @override
  Widget build(BuildContext context) {
    const double h = 110;
    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          const double node = 64;
          const leftCenter = Offset(node / 2 + 4, h / 2);
          final rightCenter = Offset(width - node / 2 - 4, h / 2);

          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              // Фази: 0–0.65 політ монетки, 0.65–1 пауза/скидання.
              final flight = (v / 0.65).clamp(0.0, 1.0);
              final t = Curves.easeInOut.transform(flight);

              final pos = Offset.lerp(leftCenter, rightCenter, t)!;
              final arc = -34 * math.sin(t * math.pi); // дуга вгору
              final coinCenter = Offset(pos.dx, pos.dy + arc);

              final coinOpacity = flight < 0.06
                  ? flight / 0.06
                  : (flight > 0.9 ? (1 - (flight - 0.9) / 0.1) : 1.0);

              // «Спалах» у цілі, коли монетка долетіла.
              final landPulse = flight > 0.92
                  ? Curves.easeOut.transform((flight - 0.92) / 0.08)
                  : 0.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _node(leftCenter, node, Icons.account_balance_wallet_rounded,
                      const Color(0xFF4B6CB7)),
                  _node(rightCenter, node + node * 0.12 * landPulse,
                      Icons.shopping_bag_rounded, const Color(0xFFE06C75)),
                  // Монетка в польоті.
                  Positioned(
                    left: coinCenter.dx - 15,
                    top: coinCenter.dy - 15,
                    child: Opacity(
                      opacity: coinOpacity.clamp(0.0, 1.0),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD874), Color(0xFFF5A623)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.paid_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Вказівник-«палець» біля монетки, натякає на перетягування.
                  Positioned(
                    left: coinCenter.dx + 2,
                    top: coinCenter.dy + 8,
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

  Widget _node(Offset center, double size, IconData icon, Color color) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}
