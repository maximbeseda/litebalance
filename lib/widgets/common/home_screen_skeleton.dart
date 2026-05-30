import 'package:flutter/material.dart';
import '../../theme/app_colors_extension.dart';

class HomeScreenSkeleton extends StatefulWidget {
  const HomeScreenSkeleton({super.key});

  @override
  State<HomeScreenSkeleton> createState() => _HomeScreenSkeletonState();
}

class _HomeScreenSkeletonState extends State<HomeScreenSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Преміальна, повільна пульсація
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPulse({
    required double width,
    required double height,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
    required Color color,
  }) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : (borderRadius ?? BorderRadius.circular(4)),
        ),
      ),
    );
  }

  // 👇 Ідеальна копія структури CoinWidget (тепер нейтрально-сіра)
  Widget _buildPulseCoin(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 14,
          child: Center(child: _buildPulse(width: 45, height: 8, color: color)),
        ),
        const SizedBox(height: 2),
        // Іконка (нейтральний сірий)
        _buildPulse(
          width: 56,
          height: 56,
          shape: BoxShape.circle,
          color: color,
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 16,
          child: Center(
            child: _buildPulse(width: 55, height: 10, color: color),
          ),
        ),
      ],
    );
  }

  // 👇 Ідеальна копія _buildSection з LayoutBuilder (тепер нейтрально-сіра)
  Widget _buildPulseSection(BuildContext context, bool isGrid, Color color) {
    final colors = Theme.of(context).extension<AppColorsExtension>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors?.cardBg ?? Colors.grey,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Легка тінь
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int crossAxisCount = (constraints.maxWidth / 80).floor().clamp(4, 8);
          final double itemWidth = (constraints.maxWidth / crossAxisCount) - 0.01;

          if (!isGrid) {
            return SizedBox(
              height: 105,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(
                  crossAxisCount,
                  (i) => SizedBox(
                    width: itemWidth,
                    height: 105,
                    child: Center(child: _buildPulseCoin(color)),
                  ),
                ),
              ),
            );
          } else {
            int rowsCount = 4;
            if (constraints.maxHeight < 380) {
              rowsCount = 3;
            } else if (constraints.maxHeight > 500) {
              rowsCount = 5;
            }
            final double itemHeight = (constraints.maxHeight / rowsCount).clamp(
              96.0,
              125.0,
            );

            return SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.start,
                children: List.generate(
                  crossAxisCount * rowsCount,
                  (i) => SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildPulseCoin(color),
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // 👇 Оновлена COMPACT SUMMARY HEADER (ОДНАКОВІ РОЗМІРИ ТА БЕЗ КОЛЬОРІВ)
  Widget _buildSummaryHeader(BuildContext context, Color color) {
    // Допоміжний віджет (тепер без параметра ширини)
    Widget buildHeaderItemMock() {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Імітація іконки
            _buildPulse(
              width: 14,
              height: 14,
              shape: BoxShape.circle,
              color: color,
            ),
            const SizedBox(width: 4),
            // 👇 ЗМІНЕНО: Тепер однаковий фіксований розмір для всіх трьох блоків
            _buildPulse(width: 50, height: 12, color: color),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 10, top: 15, bottom: 0),
      child: Row(
        children: [
          // 👇 ЗМІНЕНО: Тепер однакові
          buildHeaderItemMock(), // Баланс
          buildHeaderItemMock(), // Доходи
          buildHeaderItemMock(), // Витрати
          Container(
            width: 24,
            alignment: Alignment.center,
            // Імітація іконки налаштувань
            child: _buildPulse(
              width: 20,
              height: 20,
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 👇 ЗМІНЕНО: Єдиний нейтральний сірий колір для всього скелетону
    final skeletonColor = isDark
        ? Colors.white.withValues(alpha: 0.12) // Світло-сірий для темної теми
        : Colors.black.withValues(alpha: 0.05); // Темно-сірий для світлої теми

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.bgGradientStart, colors.bgGradientEnd],
        ),
      ),
      child: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            _buildSummaryHeader(context, skeletonColor),
            _buildPulseSection(context, false, skeletonColor),
            _buildPulseSection(context, false, skeletonColor),
            Expanded(
              child: _buildPulseSection(context, true, skeletonColor),
            ),
          ],
        ),
      ),
    );
  }
}
