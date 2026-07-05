import 'package:flutter/material.dart';

/// Список з плавними анімаціями додавання та видалення елементів.
///
/// Обгортка над [AnimatedList], яка сама відстежує зміни у [items] (за
/// стабільним ключем [keyOf]) і програє анімацію вставки для нових елементів
/// та згортання для видалених. Початкове наповнення показується без анімації
/// (швидко й без навантаження при відкритті екрана).
class AnimatedItemList<T> extends StatefulWidget {
  final List<T> items;

  /// Стабільний унікальний ключ елемента (напр. id), за яким рахуються
  /// додавання/видалення.
  final Object Function(T item) keyOf;

  /// Будує вміст елемента (без анімаційних обгорток — їх додає список сам).
  final Widget Function(BuildContext context, T item) itemBuilder;

  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Duration insertDuration;
  final Duration removeDuration;

  const AnimatedItemList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.insertDuration = const Duration(milliseconds: 350),
    this.removeDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedItemList<T>> createState() => _AnimatedItemListState<T>();
}

class _AnimatedItemListState<T> extends State<AnimatedItemList<T>> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Локальна копія списку, синхронізована з анімаціями вставки/видалення.
  late List<T> _items;

  @override
  void initState() {
    super.initState();
    _items = List<T>.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant AnimatedItemList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItems(widget.items);
  }

  void _syncItems(List<T> newItems) {
    final state = _listKey.currentState;
    if (state == null) {
      // Список ще не побудовано — просто оновлюємо дані.
      _items = List<T>.of(newItems);
      return;
    }

    final newKeys = newItems.map(widget.keyOf).toSet();

    // 1. Видалення (з кінця, щоб індекси не "поповзли").
    for (int i = _items.length - 1; i >= 0; i--) {
      if (!newKeys.contains(widget.keyOf(_items[i]))) {
        final removed = _items.removeAt(i);
        state.removeItem(
          i,
          (context, animation) =>
              _wrap(animation, widget.itemBuilder(context, removed)),
          duration: widget.removeDuration,
        );
      }
    }

    // 2. Вставлення нових (у порядку появи).
    final curKeys = _items.map(widget.keyOf).toSet();
    for (int i = 0; i < newItems.length; i++) {
      final key = widget.keyOf(newItems[i]);
      if (!curKeys.contains(key)) {
        final insertAt = i <= _items.length ? i : _items.length;
        _items.insert(insertAt, newItems[i]);
        state.insertItem(insertAt, duration: widget.insertDuration);
        curKeys.add(key);
      }
    }

    // 3. Оновлення даних наявних елементів (напр. після редагування),
    //    без анімації.
    for (int i = 0; i < _items.length; i++) {
      final idx = newItems.indexWhere(
        (e) => widget.keyOf(e) == widget.keyOf(_items[i]),
      );
      if (idx != -1) _items[i] = newItems[idx];
    }
  }

  Widget _wrap(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(opacity: curved, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      controller: widget.controller,
      physics: widget.physics,
      padding: widget.padding,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) =>
          _wrap(animation, widget.itemBuilder(context, _items[index])),
    );
  }
}
