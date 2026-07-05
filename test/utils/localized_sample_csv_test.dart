// Validates the localized sample-import CSVs in docs/sample_data/localized/.
//
// Each row's category type is inferred by the import wizard via
// ImportRecognizer.guessType(name, isFrom: false). For the demo files to import
// cleanly (no manual reclassification while shooting localized screenshots),
// every account/income category name must carry a recognized keyword, and no
// expense name may accidentally hit an income/account keyword.
//
// Row semantics in the source file:
//   Expense:  From = account, To = expense
//   Income:   From = income,  To = account
//   Transfer: From = account, To = account

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/utils/import_recognizer.dart';

const _locales = [
  'en', 'uk', 'de', 'fr', 'es', 'pt', 'pl', 'tr', 'id', 'ja', 'hi', 'ar', 'zh',
];

void main() {
  group('Localized sample CSVs classify cleanly', () {
    for (final loc in _locales) {
      test('[$loc] every category resolves to the intended type', () {
        final file = File('docs/sample_data/localized/litebalance_sample_$loc.csv');
        expect(file.existsSync(), isTrue, reason: 'missing file for $loc');

        final expected = <String, CategoryType>{};
        void want(String name, CategoryType type) {
          final n = name.trim();
          if (n.isEmpty) return;
          expected[n] = type; // later rows just reconfirm
        }

        final lines = file.readAsLinesSync();
        for (var i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          final c = lines[i].split(',');
          final type = c[1];
          final from = c[2];
          final to = c[5];
          if (type == 'Expense') {
            want(from, CategoryType.account);
            want(to, CategoryType.expense);
          } else if (type == 'Income') {
            want(from, CategoryType.income);
            want(to, CategoryType.account);
          } else if (type == 'Transfer') {
            want(from, CategoryType.account);
            want(to, CategoryType.account);
          }
        }

        expect(expected, isNotEmpty);
        final wrong = <String>[];
        expected.forEach((name, type) {
          final got = ImportRecognizer.guessType(name, isFrom: false);
          if (got != type) wrong.add('"$name": expected $type, got $got');
        });
        expect(wrong, isEmpty, reason: wrong.join('\n'));

        // Every category should also resolve to a real icon (not the default
        // Icons.category), so imported categories don't look blank.
        final noIcon = expected.keys
            .where((n) =>
                ImportRecognizer.getIconForName(n) == Icons.category.codePoint)
            .toList();
        expect(noIcon, isEmpty,
            reason: 'no icon matched for: ${noIcon.join(", ")}');
      });
    }
  });
}
