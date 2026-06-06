import 'package:flutter/material.dart';

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

/// Єдина нижня шторка-пікер у застосунку: ручка + заголовок + список
/// варіантів із галочкою на обраному. Обмежена за висотою, щоб не залазити
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
  }) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
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
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final bool isSelected = option.value == selected;
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
                                color: isSelected ? color : colors.textMain,
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
                        Navigator.pop(ctx);
                        if (!isSelected) onSelected(option.value);
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
