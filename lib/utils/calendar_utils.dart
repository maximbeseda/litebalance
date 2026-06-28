import 'package:flutter/material.dart';

/// Locale-aware first-day-of-week helpers for the app's calendars.
///
/// The canonical source is [MaterialLocalizations.firstDayOfWeekIndex], which
/// flutter_localizations resolves per locale (Monday in most of Europe, Sunday
/// in the US/much of Asia, Saturday in many RTL locales). Its convention is
/// 0 = Sunday … 6 = Saturday — different from [DateTime.weekday] (Mon=1 … Sun=7),
/// so these helpers bridge the two.
class CalendarUtils {
  CalendarUtils._();

  /// easy_localization weekday keys indexed by Material's weekday index
  /// (0 = Sunday … 6 = Saturday).
  static const List<String> _weekdayKeysSundayFirst = [
    'week_su',
    'week_mo',
    'week_tu',
    'week_we',
    'week_th',
    'week_fr',
    'week_sa',
  ];

  /// First day of week for the active locale: 0 = Sunday … 6 = Saturday.
  static int firstDayOfWeekIndex(BuildContext context) =>
      MaterialLocalizations.of(context).firstDayOfWeekIndex;

  /// Weekday translation keys ordered to start on the locale's first day.
  /// E.g. Monday-first → [week_mo … week_su]; Saturday-first → [week_sa, week_su, …].
  static List<String> orderedWeekdayKeys(int firstDayOfWeekIndex) => [
        for (int i = 0; i < 7; i++)
          _weekdayKeysSundayFirst[(firstDayOfWeekIndex + i) % 7],
      ];

  /// Number of empty leading cells before [firstOfMonth] in a month grid whose
  /// first column is [firstDayOfWeekIndex].
  static int leadingOffset(DateTime firstOfMonth, int firstDayOfWeekIndex) {
    // DateTime.weekday (Mon=1 … Sun=7) → Material index (Sun=0 … Sat=6).
    final int materialWeekday = firstOfMonth.weekday % 7;
    return (materialWeekday - firstDayOfWeekIndex + 7) % 7;
  }
}
