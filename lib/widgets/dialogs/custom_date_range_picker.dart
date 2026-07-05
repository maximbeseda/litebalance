import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/calendar_utils.dart';

// Сигнальний об'єкт для скидання фільтра
class ResetRangeSignal {}

class _DayModel {
  final DateTime date;
  final int value;
  final String text;
  final bool isFuture;

  const _DayModel({
    required this.date,
    required this.value,
    required this.text,
    required this.isFuture,
  });
}

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialRange;
  final AppColorsExtension colors;

  const CustomDateRangePicker({
    super.key,
    required this.initialRange,
    required this.colors,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  DateTime? _start;
  DateTime? _end;

  int? _startInt;
  int? _endInt;
  late int _todayInt;

  final List<dynamic> _flatItems = [];
  late DateFormat _monthFormat;

  /// Перший день тижня за локаллю (0=Нд…6=Сб). Встановлюється у
  /// didChangeDependencies перед генерацією сітки.
  int _firstDow = 1;

  Color get highlightColor => widget.colors.accent;

  int _dateToInt(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;

    if (_start != null) _startInt = _dateToInt(_start!);
    if (_end != null) _endInt = _dateToInt(_end!);

    final now = DateTime.now();
    _todayInt = _dateToInt(now);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 👇 ВИПРАВЛЕНО: Безпечне отримання локалі для тестів
    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    _monthFormat = DateFormat('LLLL yyyy', localeCode);
    _firstDow = CalendarUtils.firstDayOfWeekIndex(context);

    if (_flatItems.isEmpty) {
      _generateFlatItems();
    }
  }

  void _generateFlatItems() {
    final now = DateTime.now();
    for (int y = now.year; y >= 2000; y--) {
      final int mStart = (y == now.year) ? now.month : 12;
      for (int m = mStart; m >= 1; m--) {
        final DateTime monthDate = DateTime(y, m, 1);
        final int daysInMonth = DateUtils.getDaysInMonth(y, m);
        final int offset = CalendarUtils.leadingOffset(monthDate, _firstDow);

        final List<List<_DayModel?>> monthWeeks = [];
        List<_DayModel?> currentWeek = List.filled(
          offset,
          null,
          growable: true,
        );

        for (int d = 1; d <= daysInMonth; d++) {
          final dt = DateTime(y, m, d);
          final val = y * 10000 + m * 100 + d;

          currentWeek.add(
            _DayModel(
              date: dt,
              value: val,
              text: d.toString(),
              isFuture: val > _todayInt,
            ),
          );

          if (currentWeek.length == 7) {
            monthWeeks.add(List<_DayModel?>.from(currentWeek));
            currentWeek = [];
          }
        }
        if (currentWeek.isNotEmpty) {
          while (currentWeek.length < 7) {
            currentWeek.add(null);
          }
          monthWeeks.add(currentWeek);
        }

        for (var week in monthWeeks.reversed) {
          _flatItems.add(week);
        }
        _flatItems.add(_monthFormat.format(monthDate).toUpperCase());
      }
    }
  }

  void _onDayTapped(DateTime date, int dateVal) {
    setState(() {
      if (_startInt == null || (_startInt != null && _endInt != null)) {
        _start = date;
        _startInt = dateVal;
        _end = null;
        _endInt = null;
      } else {
        if (dateVal < _startInt!) {
          _end = _start;
          _endInt = _startInt;
          _start = date;
          _startInt = dateVal;
        } else if (dateVal == _startInt!) {
          _end = _start;
          _endInt = _startInt;
        } else {
          _end = date;
          _endInt = dateVal;
        }
      }
    });
  }

  String _formatHeader() {
    if (_start == null) return 'filter_select_period'.tr();
    // 👇 ВИПРАВЛЕНО: Безпечне отримання локалі для тестів
    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    final s = DateFormat('dd MMM yyyy', localeCode).format(_start!);
    if (_end == null) return s;
    final e = DateFormat('dd MMM yyyy', localeCode).format(_end!);
    return '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    final double cellWidth = (MediaQuery.of(context).size.width - 32) / 7;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: widget.colors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 👇 ВИПРАВЛЕНО: Додано Expanded та обмеження рядків
                    Expanded(
                      child: Text(
                        'filter_period'.tr(),
                        style: TextStyle(
                          color: widget.colors.textMain,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, ResetRangeSignal()),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Text(
                          'reset'.tr(),
                          style: TextStyle(
                            color: widget.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatHeader(),
                  style: TextStyle(
                    color: highlightColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Weekdays
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children:
                  CalendarUtils.orderedWeekdayKeys(_firstDow)
                      .map((k) => k.tr())
                      .map(
                        (d) => SizedBox(
                          width: cellWidth,
                          child: Center(
                            // 👇 ВИПРАВЛЕНО: Додано FittedBox, щоб текст днів не вилазив за межі
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                d,
                                style: TextStyle(
                                  color: widget.colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _flatItems.length,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = _flatItems[index];
                if (item is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: widget.colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  );
                } else {
                  final List<_DayModel?> week = item;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: week
                        .map(
                          (d) => _DayCellWidget(
                            day: d,
                            cellWidth: cellWidth,
                            startInt: _startInt,
                            endInt: _endInt,
                            highlightColor: highlightColor,
                            colors: widget.colors,
                            onTap: () => _onDayTapped(d!.date, d.value),
                          ),
                        )
                        .toList(),
                  );
                }
              },
            ),
          ),

          // Bottom Button
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlightColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _start == null
                    ? null
                    : () {
                        Navigator.pop(
                          context,
                          DateTimeRange(start: _start!, end: _end ?? _start!),
                        );
                      },
                child: Text(
                  'apply'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCellWidget extends StatelessWidget {
  final _DayModel? day;
  final double cellWidth;
  final int? startInt;
  final int? endInt;
  final Color highlightColor;
  final AppColorsExtension colors;
  final VoidCallback onTap;

  const _DayCellWidget({
    required this.day,
    required this.cellWidth,
    required this.startInt,
    required this.endInt,
    required this.highlightColor,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (day == null) return SizedBox(width: cellWidth, height: 44);

    final bool isStart = startInt == day!.value;
    final bool isEnd = endInt == day!.value;
    final bool inRange =
        startInt != null &&
        endInt != null &&
        day!.value > startInt! &&
        day!.value < endInt!;
    final bool isSelected = isStart || isEnd || inRange;

    BoxDecoration decoration = const BoxDecoration();
    if (isSelected) {
      if (isStart && isEnd) {
        decoration = BoxDecoration(
          color: highlightColor,
          shape: BoxShape.circle,
        );
      } else if (isStart && endInt == null) {
        decoration = BoxDecoration(
          color: highlightColor,
          shape: BoxShape.circle,
        );
      } else if (isStart) {
        decoration = BoxDecoration(
          color: highlightColor,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(100),
          ),
        );
      } else if (isEnd) {
        decoration = BoxDecoration(
          color: highlightColor,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(100),
          ),
        );
      } else {
        decoration = BoxDecoration(color: highlightColor);
      }
    }

    return SizedBox(
      width: cellWidth,
      child: GestureDetector(
        onTap: day!.isFuture ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: decoration,
          alignment: Alignment.center,
          child: Text(
            day!.text,
            style: TextStyle(
              color: day!.isFuture
                  ? colors.textSecondary.withValues(alpha: 0.3)
                  : (isSelected ? Colors.white : colors.textMain),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
