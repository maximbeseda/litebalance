import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors_extension.dart';

class PremiumDatePicker extends StatefulWidget {
  final DateTime initialDate;

  const PremiumDatePicker({super.key, required this.initialDate});

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: colors.cardBg,
      elevation: 0,
      isScrollControlled: true,
      builder: (ctx) => PremiumDatePicker(initialDate: initialDate),
    );
  }

  @override
  State<PremiumDatePicker> createState() => _PremiumDatePickerState();
}

class _PremiumDatePickerState extends State<PremiumDatePicker> {
  late DateTime _tempSelectedDate;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  final int _startYear = 2000;
  final int _endYear = 2100;
  final double _itemHeight = 38;

  @override
  void initState() {
    super.initState();
    _tempSelectedDate = widget.initialDate;
    _yearController = FixedExtentScrollController(
      initialItem: _tempSelectedDate.year - _startYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _tempSelectedDate.month - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _tempSelectedDate.day - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _updateDate() {
    setState(() {
      final int year = _startYear + _yearController.selectedItem;
      final int month = _monthController.selectedItem + 1;
      int day = _dayController.selectedItem + 1;
      final int lastDay = DateTime(year, month + 1, 0).day;
      if (day > lastDay) day = lastDay;
      _tempSelectedDate = DateTime(year, month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    // 👇 ВИПРАВЛЕНО: Безпечне отримання локалі для тестів
    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    return Padding(
      // Додаємо padding знизу для безпечних зон (наприклад, на iPhone)
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Container(
        // Використовуємо Wrap або Column з min розміром, щоб уникнути overflow
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Шторка облягає контент
          children: [
            Container(
              width: 35,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'choose_date'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'date'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.yMMMEd(localeCode).format(_tempSelectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colors.textMain,
                  foregroundColor: colors.cardBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, _tempSelectedDate),
                child: Text(
                  'update_date'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 175,
              child: Row(
                children: [
                  _buildPickerWithIsland(
                    controller: _yearController,
                    items: List.generate(
                      _endYear - _startYear + 1,
                      (i) => '${_startYear + i}',
                    ),
                    colors: colors,
                    overlayWidth: 65,
                  ),
                  const SizedBox(width: 10),
                  _buildPickerWithIsland(
                    controller: _monthController,
                    items: List.generate(12, (i) => '${i + 1}'.padLeft(2, '0')),
                    colors: colors,
                    overlayWidth: 65,
                  ),
                  const SizedBox(width: 10),
                  _buildPickerWithIsland(
                    controller: _dayController,
                    items: List.generate(31, (i) => '${i + 1}'.padLeft(2, '0')),
                    colors: colors,
                    overlayWidth: 65,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerWithIsland({
    required FixedExtentScrollController controller,
    required List<String> items,
    required AppColorsExtension colors,
    required double overlayWidth,
  }) {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: overlayWidth,
            height: 46,
            decoration: BoxDecoration(
              color: colors.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          CupertinoPicker(
            scrollController: controller,
            itemExtent: _itemHeight,
            selectionOverlay: const SizedBox(),
            diameterRatio: 1,
            squeeze: 1.5,
            onSelectedItemChanged: (_) => _updateDate(),
            children: items
                .map(
                  (text) => Center(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
