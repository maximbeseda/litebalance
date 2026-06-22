import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/app_colors_extension.dart';

/// Один варіант вибору в [AppPickerSheet].
class AppPickerOption<T> {
  final T value;
  final String label;

  /// Опційний значок ліворуч (напр. [AppPill] з кодом валюти/мови).
  final Widget? leading;

  /// Колір виділення для обраного елемента (за замовчуванням — accent).
  final Color? color;

  /// Опційний маленький текстовий бейдж біля назви (напр. «базова»).
  final String? badge;

  const AppPickerOption({
    required this.value,
    required this.label,
    this.leading,
    this.color,
    this.badge,
  });
}

/// Єдина нижня шторка-пікер у застосунку: ручка + заголовок + (опційно) пошук +
/// список варіантів із галочкою на обраному. Обмежена за висотою, щоб не залазити
/// на системний рядок. Замінює дубльований патерн у профілі, категоріях,
/// підписках та курсах валют.
class AppPickerSheet {
  const AppPickerSheet._();

  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    required T selected,
    required List<AppPickerOption<T>> options,
    required ValueChanged<T> onSelected,
    double maxHeightFactor = 0.85,
    bool enableSearch = false,
    Widget? emptyState,
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => _PickerSheetBody<T>(
        title: title,
        selected: selected,
        options: options,
        onSelected: onSelected,
        maxHeightFactor: maxHeightFactor,
        enableSearch: enableSearch,
        emptyState: emptyState,
        colors: colors,
      ),
    );
  }
}

class _PickerSheetBody<T> extends StatefulWidget {
  final String title;
  final T selected;
  final List<AppPickerOption<T>> options;
  final ValueChanged<T> onSelected;
  final double maxHeightFactor;
  final bool enableSearch;
  final Widget? emptyState;
  final AppColorsExtension colors;

  const _PickerSheetBody({
    super.key,
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
    required this.maxHeightFactor,
    required this.enableSearch,
    required this.emptyState,
    required this.colors,
  });

  @override
  State<_PickerSheetBody<T>> createState() => _PickerSheetBodyState<T>();
}

class _PickerSheetBodyState<T> extends State<_PickerSheetBody<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppPickerOption<T>> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    final q = _query.trim().toLowerCase();
    // Пошук і за назвою (label), і за тікером/кодом (value).
    return widget.options
        .where(
          (o) =>
              o.label.toLowerCase().contains(q) ||
              o.value.toString().toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final filtered = _filtered;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * widget.maxHeightFactor,
      ),
      child: Padding(
        // Піднімаємо шторку над клавіатурою при пошуку.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.enableSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: false,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: colors.textMain, fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'search'.tr(),
                      hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: colors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: colors.textSecondary.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: filtered.isEmpty
                    ? (_query.trim().isEmpty && widget.emptyState != null
                          ? widget.emptyState!
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'no_data'.tr(),
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final bool isSelected =
                              option.value == widget.selected;
                          final Color color = option.color ?? colors.accent;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            leading: option.leading,
                            minLeadingWidth: 0,
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : colors.textMain,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (option.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      option.badge!,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_rounded, color: color)
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              if (!isSelected) widget.onSelected(option.value);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
