import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/utils/calendar_utils.dart';

void main() {
  group('CalendarUtils.orderedWeekdayKeys', () {
    test('Monday-first (1) → Mon … Sun', () {
      expect(CalendarUtils.orderedWeekdayKeys(1), [
        'week_mo',
        'week_tu',
        'week_we',
        'week_th',
        'week_fr',
        'week_sa',
        'week_su',
      ]);
    });

    test('Sunday-first (0) → Sun … Sat', () {
      expect(CalendarUtils.orderedWeekdayKeys(0), [
        'week_su',
        'week_mo',
        'week_tu',
        'week_we',
        'week_th',
        'week_fr',
        'week_sa',
      ]);
    });

    test('Saturday-first (6) → Sat, Sun, Mon …', () {
      expect(CalendarUtils.orderedWeekdayKeys(6), [
        'week_sa',
        'week_su',
        'week_mo',
        'week_tu',
        'week_we',
        'week_th',
        'week_fr',
      ]);
    });
  });

  group('CalendarUtils.leadingOffset', () {
    // 2024-01-01 was a Monday; 2023-01-01 was a Sunday.
    final monday = DateTime(2024, 1, 1);
    final sunday = DateTime(2023, 1, 1);

    test('Monday start, Monday-first → 0 leading cells', () {
      expect(CalendarUtils.leadingOffset(monday, 1), 0);
    });

    test('Monday start, Sunday-first → 1 leading cell', () {
      expect(CalendarUtils.leadingOffset(monday, 0), 1);
    });

    test('Sunday start, Monday-first → 6 leading cells', () {
      expect(CalendarUtils.leadingOffset(sunday, 1), 6);
    });

    test('Sunday start, Sunday-first → 0 leading cells', () {
      expect(CalendarUtils.leadingOffset(sunday, 0), 0);
    });

    test('Sunday start, Saturday-first → 1 leading cell', () {
      expect(CalendarUtils.leadingOffset(sunday, 6), 1);
    });
  });

  group('CalendarUtils.firstDayOfWeekIndex (locale-aware)', () {
    Future<int> resolve(WidgetTester tester, Locale locale) async {
      late int result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('de'),
            Locale('ar'),
          ],
          locale: locale,
          home: Builder(
            builder: (context) {
              result = CalendarUtils.firstDayOfWeekIndex(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('en_US starts the week on Sunday (0)', (tester) async {
      expect(await resolve(tester, const Locale('en', 'US')), 0);
    });

    testWidgets('de starts the week on Monday (1)', (tester) async {
      expect(await resolve(tester, const Locale('de')), 1);
    });

    testWidgets('ar starts the week on Saturday (6)', (tester) async {
      expect(await resolve(tester, const Locale('ar')), 6);
    });
  });
}
