import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/all_providers.dart';
import '../../theme/app_colors_extension.dart';

class HistorySearchBar extends ConsumerStatefulWidget {
  final CategoryType? specificType;

  const HistorySearchBar({super.key, this.specificType});

  @override
  ConsumerState<HistorySearchBar> createState() => _HistorySearchBarState();
}

class _HistorySearchBarState extends ConsumerState<HistorySearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Перемальовуємо при зміні фокуса (акцентна рамка та іконка).
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialQuery = ref.read(filterProvider).searchQuery;
      if (initialQuery.isNotEmpty) {
        _searchController.text = initialQuery;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(filterProvider.notifier).setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final isDark = theme.brightness == Brightness.dark;

    final bool hasText = _searchController.text.isNotEmpty;
    final bool isActive = _focusNode.hasFocus || hasText;

    const radius = BorderRadius.all(Radius.circular(8));
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colors.textSecondary.withValues(alpha: 0.06);
    final accentColor = isActive ? colors.accent : colors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: (isActive && !isDark)
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        cursorColor: colors.accent,
        style: TextStyle(color: colors.textMain, fontSize: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          isDense: true,
          hintText: 'search_transactions'.tr(),
          hintStyle: TextStyle(color: colors.textSecondary),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: accentColor,
            size: 22,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 18,
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _focusNode.unfocus();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: colors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}
