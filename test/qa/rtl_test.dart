// RTL (right-to-left) regression tests for the four RTL locales the app ships:
// Arabic (ar), Persian (fa), Urdu (ur), Hebrew (he).
//
// These guard the two classes of bugs fixed when RTL support landed:
//   1. Amounts are LTR content (digits, separators, '-', currency symbol). Inside
//      an RTL Directionality the bidi algorithm reorders them, so every amount
//      widget must force TextDirection.ltr. We assert that here for the shared
//      AmountText helper — the regression guard for the central fix.
//   2. The RTL locales must actually resolve to TextDirection.rtl in a real
//      MaterialApp wired with the global localization delegates, so the rest of
//      the UI mirrors. We assert that end-to-end.
//
// Plus a translation-completeness check: each RTL file must carry exactly the
// same key set (and currency list) as the English reference, so no string falls
// back / renders a raw key in production.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/utils/amount_text.dart';

const _rtlLocales = ['ar', 'fa', 'ur', 'he'];

void main() {
  group('AmountText forces LTR regardless of ambient direction', () {
    for (final dir in TextDirection.values) {
      testWidgets('renders LTR inside ${dir.name} Directionality',
          (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: dir,
            child: const Center(
              child: AmountText(
                amount: '-1 234,56',
                symbol: '₪',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        );

        // Text.rich builds a RichText; its resolved direction must be LTR so the
        // number and the trailing currency symbol never get reordered.
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect(richText.textDirection, TextDirection.ltr);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('RTL locales resolve to TextDirection.rtl in the app', () {
    for (final code in _rtlLocales) {
      testWidgets('"$code" yields an RTL Directionality', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale(code), const Locale('en')],
            locale: Locale(code),
            home: Builder(
              builder: (context) => Text(
                Directionality.of(context) == TextDirection.rtl
                    ? 'rtl'
                    : 'ltr',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('rtl'), findsOneWidget);
      });
    }
  });

  group('RTL translation files match the English reference', () {
    Map<String, dynamic> readJson(String locale) {
      final raw = File('assets/translations/$locale.json').readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final en = readJson('en');
    final enKeys = en.keys.toSet();
    final enCurrencies =
        (en['currency_names'] as Map<String, dynamic>).keys.toSet();

    for (final code in _rtlLocales) {
      group('[$code]', () {
        final tr = readJson(code);

        test('has exactly the same top-level keys as en', () {
          final keys = tr.keys.toSet();
          expect(keys.difference(enKeys), isEmpty,
              reason: 'extra keys not present in en.json');
          expect(enKeys.difference(keys), isEmpty,
              reason: 'missing keys present in en.json');
        });

        test('covers every currency name with a non-empty value', () {
          final currencies = tr['currency_names'] as Map<String, dynamic>;
          for (final c in enCurrencies) {
            expect(currencies.containsKey(c), isTrue,
                reason: 'missing currency $c');
            expect((currencies[c] as String).trim(), isNotEmpty,
                reason: 'empty name for currency $c');
          }
        });

        test('preserves {} / \\n placeholders from en for every string', () {
          for (final key in enKeys) {
            final enVal = en[key];
            if (enVal is! String) continue; // skip currency_names map
            final trVal = tr[key];
            expect(trVal, isA<String>(), reason: '$key should be a string');
            expect((trVal as String).contains('{}'), enVal.contains('{}'),
                reason: 'placeholder {} mismatch in "$key"');
            expect(trVal.contains('\n'), enVal.contains('\n'),
                reason: 'newline placeholder mismatch in "$key"');
          }
        });
      });
    }
  });
}
