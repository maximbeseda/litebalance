import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/calendar_utils.dart';

enum CalendarMode { date, month, year }

class CustomCalendarDialog extends StatefulWidget {
  final DateTime initialDate;

  const CustomCalendarDialog({super.key, required this.initialDate});

  @override
  State<CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<CustomCalendarDialog> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  CalendarMode _mode = CalendarMode.date;

  // 👇 ВИПРАВЛЕНО: Безпечне отримання локалі, яке не "вбиває" тести
  String _getMonthName(int month, BuildContext context) {
    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final String m = DateFormat.LLLL(localeCode).format(DateTime(2000, month));
    return m[0].toUpperCase() + m.substring(1);
  }

  final int _startYear = 2000;
  final int _endYear = DateTime.now().year + 100;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final invertedTextColor = Theme.of(context).scaffoldBackgroundColor;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'select_date'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // --- ШАПКА ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Opacity(
                    opacity: _mode == CalendarMode.date ? 1.0 : 0.0,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: Icon(Icons.chevron_left, color: colors.textMain),
                      onPressed: _mode == CalendarMode.date
                          ? () => setState(
                              () => _focusedDay = DateTime(
                                _focusedDay.year,
                                _focusedDay.month - 1,
                                1,
                              ),
                            )
                          : null,
                    ),
                  ),

                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _mode = _mode == CalendarMode.month
                                  ? CalendarMode.date
                                  : CalendarMode.month,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _mode == CalendarMode.month
                                    ? colors.textMain
                                    : colors.iconBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _getMonthName(_focusedDay.month, context),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _mode == CalendarMode.month
                                            ? invertedTextColor
                                            : colors.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    _mode == CalendarMode.month
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: _mode == CalendarMode.month
                                        ? invertedTextColor
                                        : colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _mode = _mode == CalendarMode.year
                                  ? CalendarMode.date
                                  : CalendarMode.year,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _mode == CalendarMode.year
                                    ? colors.textMain
                                    : colors.iconBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _focusedDay.year.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _mode == CalendarMode.year
                                          ? invertedTextColor
                                          : colors.textMain,
                                    ),
                                  ),
                                  Icon(
                                    _mode == CalendarMode.year
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: _mode == CalendarMode.year
                                        ? invertedTextColor
                                        : colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Opacity(
                    opacity: _mode == CalendarMode.date ? 1.0 : 0.0,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: Icon(Icons.chevron_right, color: colors.textMain),
                      onPressed: _mode == CalendarMode.date
                          ? () => setState(
                              () => _focusedDay = DateTime(
                                _focusedDay.year,
                                _focusedDay.month + 1,
                                1,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- КОНТЕНТ ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(colors, invertedTextColor),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'cancel'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedDay),
                      child: Text(
                        'ok'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppColorsExtension colors, Color invertedTextColor) {
    switch (_mode) {
      case CalendarMode.month:
        return _buildMonthGrid(colors, invertedTextColor);
      case CalendarMode.year:
        return _buildYearGrid(colors, invertedTextColor);
      case CalendarMode.date:
        return _buildCalendar(colors, invertedTextColor);
    }
  }

  Widget _buildCalendar(AppColorsExtension colors, Color invertedTextColor) {
    // 👇 ВИПРАВЛЕНО: Безпечне отримання локалі
    final localeCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    return TableCalendar(
      key: const ValueKey('calendar'),
      locale: localeCode,
      firstDay: DateTime.utc(_startYear, 1, 1),
      lastDay: DateTime.utc(_endYear, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: 46,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      // Перший день тижня — за локаллю (пн у Європі, нд у США/Азії, сб у
      // багатьох RTL-локалях). Material: 0=Нд…6=Сб → enum table_calendar:
      // monday=0…sunday=6, тож зсув (+6)%7.
      startingDayOfWeek: StartingDayOfWeek
          .values[(CalendarUtils.firstDayOfWeekIndex(context) + 6) % 7],
      headerVisible: false,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
        weekendStyle: TextStyle(color: colors.expense, fontSize: 12),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: TextStyle(
          color: colors.textSecondary.withValues(alpha: 0.5),
        ),
        defaultTextStyle: TextStyle(
          color: colors.textMain,
          fontWeight: FontWeight.w500,
        ),
        weekendTextStyle: TextStyle(
          color: colors.expense,
          fontWeight: FontWeight.w500,
        ),
        cellMargin: const EdgeInsets.all(2.0),
        selectedDecoration: BoxDecoration(
          color: colors.textMain,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: invertedTextColor,
          fontWeight: FontWeight.bold,
        ),
        todayDecoration: BoxDecoration(
          color: colors.iconBg,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: colors.textMain,
          fontWeight: FontWeight.bold,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
    );
  }

  Widget _buildMonthGrid(AppColorsExtension colors, Color invertedTextColor) {
    return GridView.builder(
      key: const ValueKey('months'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final bool isSelected = _focusedDay.month == index + 1;
        return GestureDetector(
          onTap: () => setState(() {
            _focusedDay = DateTime(_focusedDay.year, index + 1, 1);
            _mode = CalendarMode.date;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.textMain : colors.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _getMonthName(index + 1, context),
                style: TextStyle(
                  color: isSelected ? invertedTextColor : colors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearGrid(AppColorsExtension colors, Color invertedTextColor) {
    return SizedBox(
      key: const ValueKey('years'),
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boxHeight = constraints.maxHeight;
          final double boxWidth = constraints.maxWidth;
          final double tileHeight = (boxWidth / 4) / 1.8;
          const double spacing = 12.0;
          final double exactOffset =
              ((_focusedDay.year - _startYear) ~/ 4) * (tileHeight + spacing);
          final double centeredOffset =
              exactOffset - (boxHeight / 2) + (tileHeight / 2);

          return GridView.builder(
            controller: ScrollController(
              initialScrollOffset: centeredOffset < 0 ? 0 : centeredOffset,
            ),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _endYear - _startYear + 1,
            itemBuilder: (context, index) {
              final int year = _startYear + index;
              final bool isSelected = _focusedDay.year == year;
              return GestureDetector(
                onTap: () => setState(() {
                  _focusedDay = DateTime(year, _focusedDay.month, 1);
                  _mode = CalendarMode.date;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? colors.textMain : colors.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: isSelected ? invertedTextColor : colors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
