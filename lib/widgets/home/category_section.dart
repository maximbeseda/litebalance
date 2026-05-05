import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../providers/all_providers.dart';
import '../../theme/app_colors_extension.dart';
import '../common/coin_widget.dart';

class DraggingCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setId(String? id) {
    state = id;
  }
}

final draggingCategoryProvider =
    NotifierProvider<DraggingCategoryNotifier, String?>(
      DraggingCategoryNotifier.new,
    );

class CategorySection extends ConsumerStatefulWidget {
  final List<Category> categories;
  final CategoryType type;
  final bool isTarget;
  final bool isGrid;

  final void Function(Category source, Category target) onTransfer;
  final void Function(Category category) onHistoryTap;
  final Future<dynamic> Function(Category category) onEditTap;
  final void Function() onAddTap;

  const CategorySection({
    super.key,
    required this.categories,
    required this.type,
    required this.onTransfer,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onAddTap,
    this.isTarget = false,
    this.isGrid = false,
  });

  @override
  ConsumerState<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<CategorySection>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _jiggleController;

  final List<String> _deletingIds = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _jiggleController.dispose();
    super.dispose();
  }

  Future<void> _handleEdit(Category c) async {
    final result = await widget.onEditTap(c);

    if (result == 'delete') {
      if (!mounted) return;
      setState(() => _deletingIds.add(c.id));
      await Future.delayed(const Duration(milliseconds: 350));
      await ref.read(categoryProvider.notifier).moveToTrash(c);
      if (mounted) setState(() => _deletingIds.remove(c.id));
    }
  }

  Widget _buildCoin(
    Category c,
    HomeScreenState homeState,
    AppColorsExtension colors,
    String? draggedCategoryId,
  ) {
    final bool isDeleting = _deletingIds.contains(c.id);
    final bool isBeingDragged = draggedCategoryId == c.id;

    final Widget dragFeedback = Material(
      color: Colors.transparent,
      child: CoinWidget(category: c, isFeedback: true, enableHero: false),
    );

    Widget buildInteractiveInnerCoin(
      Widget normalCoin,
      Widget placeholderCoin,
    ) {
      if (homeState.isEditMode || c.type == CategoryType.expense) {
        return normalCoin;
      }
      return Draggable<Category>(
        data: c,
        maxSimultaneousDrags: 1,
        onDragStarted: () =>
            ref.read(draggingCategoryProvider.notifier).setId(c.id),
        // 👇 ДОДАНО: Підстраховка при завершенні та успішному дропі
        onDragEnd: (_) =>
            ref.read(draggingCategoryProvider.notifier).setId(null),
        onDragCompleted: () =>
            ref.read(draggingCategoryProvider.notifier).setId(null),
        onDraggableCanceled: (_, _) =>
            ref.read(draggingCategoryProvider.notifier).setId(null),
        feedback: dragFeedback,
        childWhenDragging: placeholderCoin,
        child: isBeingDragged ? placeholderCoin : normalCoin,
      );
    }

    Widget buildContent(bool isHovered) {
      Widget coin = AnimatedScale(
        duration: const Duration(milliseconds: 300),
        scale: isDeleting ? 0.0 : 1.0,
        curve: Curves.easeInBack,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isDeleting ? 0.0 : 1.0,
          child: CoinWidget(
            category: c,
            isHovered: isHovered,
            coinWrapper: buildInteractiveInnerCoin,
          ),
        ),
      );

      if (homeState.isEditMode) {
        coin = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            coin,
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _handleEdit(c),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ],
        );
        coin = AnimatedBuilder(
          animation: _jiggleController,
          builder: (context, child) => Transform.rotate(
            angle: math.sin(_jiggleController.value * math.pi * 2) * 0.04,
            child: child,
          ),
          child: coin,
        );
      }

      final Widget emptySpace = Opacity(opacity: 0.0, child: coin);
      final Widget dragFeedbackReorder = Material(
        color: Colors.transparent,
        child: CoinWidget(category: c, enableHero: false),
      );

      if (homeState.isEditMode) {
        return GestureDetector(
          onTap: () {
            ref.read(homeScreenControllerProvider.notifier).toggleEditMode();
          },
          child: Draggable<Category>(
            data: c,
            maxSimultaneousDrags: 1,
            onDragStarted: () =>
                ref.read(draggingCategoryProvider.notifier).setId(c.id),
            // 👇 ДОДАНО: Підстраховка
            onDragEnd: (_) =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            onDragCompleted: () =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            onDraggableCanceled: (_, _) =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            feedback: dragFeedbackReorder,
            childWhenDragging: emptySpace,
            child: isBeingDragged ? emptySpace : coin,
          ),
        );
      } else {
        return GestureDetector(
          onTap: () => widget.onHistoryTap(c),
          child: LongPressDraggable<Category>(
            data: c,
            maxSimultaneousDrags: 1,
            delay: const Duration(milliseconds: 500),
            onDragStarted: () async {
              if (await Vibration.hasVibrator() == true) {
                unawaited(Vibration.vibrate(duration: 15, amplitude: 40));
              }
              ref.read(homeScreenControllerProvider.notifier).toggleEditMode();
              ref.read(draggingCategoryProvider.notifier).setId(c.id);
            },
            // 👇 ДОДАНО: Підстраховка
            onDragEnd: (_) =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            onDragCompleted: () =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            onDraggableCanceled: (_, _) =>
                ref.read(draggingCategoryProvider.notifier).setId(null),
            feedback: dragFeedbackReorder,
            childWhenDragging: emptySpace,
            child: coin,
          ),
        );
      }
    }

    return KeyedSubtree(
      key: ValueKey(c.id),
      child: (widget.isTarget || homeState.isEditMode)
          ? DragTarget<Category>(
              onWillAcceptWithDetails: (details) {
                final source = details.data;
                if (source.id == c.id) return false;
                final bool isSameGroup = source.type == c.type;
                if (homeState.isEditMode) {
                  if (isSameGroup) {
                    ref
                        .read(categoryProvider.notifier)
                        .reorderCategories(source, c);
                    return true;
                  }
                  return false;
                } else {
                  if (isSameGroup) return source.type == CategoryType.account;
                  return !(source.type == CategoryType.income &&
                          c.type == CategoryType.expense) &&
                      source.type != CategoryType.expense;
                }
              },
              onAcceptWithDetails: (d) {
                // 👇 ГОЛОВНИЙ ФІКС: Примусово очищаємо тінь ДО того, як відкриється екран транзакції
                ref.read(draggingCategoryProvider.notifier).setId(null);

                if (!homeState.isEditMode) {
                  final source = d.data;
                  if (source.type == c.type &&
                      source.type != CategoryType.account) {
                    return;
                  }
                  widget.onTransfer(source, c);
                }
              },
              builder: (_, candidateData, _) =>
                  buildContent(candidateData.isNotEmpty),
            )
          : buildContent(false),
    );
  }

  Widget _buildAddBtn(HomeScreenState homeState, AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        if (homeState.isEditMode) {
          ref.read(homeScreenControllerProvider.notifier).toggleEditMode();
          return;
        }
        widget.onAddTap();
      },
      child: Opacity(
        opacity: homeState.isEditMode ? 0.3 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: colors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: colors.textSecondary, size: 24),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final homeState = ref.watch(homeScreenControllerProvider);

    final draggedCategoryId = ref.watch(draggingCategoryProvider);

    ref.listen(homeScreenControllerProvider.select((s) => s.isEditMode), (
      prev,
      next,
    ) {
      if (next) {
        _jiggleController.repeat();
      } else {
        _jiggleController.stop();
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int crossAxisCount = (constraints.maxWidth / 80).floor().clamp(
            4,
            8,
          );
          final items = [
            ...widget.categories.map(
              (c) => _buildCoin(c, homeState, colors, draggedCategoryId),
            ),
            _buildAddBtn(homeState, colors),
          ];

          Widget pageView;
          if (!widget.isGrid) {
            final int perPage = crossAxisCount;
            final double itemWidth = (constraints.maxWidth / perPage) - 0.01;
            pageView = SizedBox(
              height: 105,
              child: PageView.builder(
                controller: _pageController,
                itemCount: (items.length / perPage).ceil(),
                itemBuilder: (ctx, p) => Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: items
                      .skip(p * perPage)
                      .take(perPage)
                      .map(
                        (i) => SizedBox(
                          width: itemWidth,
                          height: 105,
                          child: Center(child: i),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          } else {
            final int rowsCount = constraints.maxHeight < 380
                ? 3
                : (constraints.maxHeight > 500 ? 5 : 4);
            final int perPage = crossAxisCount * rowsCount;
            final double itemWidth =
                (constraints.maxWidth / crossAxisCount) - 0.01;
            final double itemHeight = (constraints.maxHeight / rowsCount).clamp(
              96.0,
              125.0,
            );

            pageView = PageView.builder(
              controller: _pageController,
              itemCount: items.isEmpty ? 1 : (items.length / perPage).ceil(),
              itemBuilder: (ctx, p) {
                final pageItems = items
                    .skip(p * perPage)
                    .take(perPage)
                    .toList();
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      children: pageItems
                          .map(
                            (item) => SizedBox(
                              width: itemWidth,
                              height: itemHeight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: item,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            );
          }

          return Stack(
            children: [
              pageView,
              if (draggedCategoryId != null) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 25,
                  child: DragTarget<Category>(
                    onWillAcceptWithDetails: (_) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      return false;
                    },
                    builder: (_, _, _) => Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 25,
                  child: DragTarget<Category>(
                    onWillAcceptWithDetails: (_) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      return false;
                    },
                    builder: (_, _, _) => Container(color: Colors.transparent),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
