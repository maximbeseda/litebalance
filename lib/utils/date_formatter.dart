import 'package:intl/intl.dart';

class DateFormatter {
  /// Коротка дата у форматі локалі (uk: 22.03.2026, en_US: 3/22/2026).
  static String formatFull(DateTime date, String locale) {
    return DateFormat.yMd(locale).format(date);
  }

  /// Дата + час, обидва за локаллю (24h або AM/PM залежно від мови).
  static String formatWithTime(DateTime date, String locale) {
    return DateFormat.yMd(locale).add_jm().format(date);
  }

  /// Назва місяця та рік: Березень 2026
  static String formatMonthYear(DateTime date, String locale) {
    final String month = DateFormat.MMMM(locale).format(date);
    return '${month[0].toUpperCase()}${month.substring(1)} ${date.year}';
  }

  /// Тільки день: 22
  static String formatDay(DateTime date) {
    return DateFormat('dd').format(date);
  }
}
