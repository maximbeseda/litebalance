import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import '../database/app_database.dart';

class ExportImportService {
  // ==========================================
  // ЧИТАННЯ CSV (Для імпорту)
  // ==========================================
  static Future<List<List<dynamic>>?> readCsvRaw(File file) async {
    try {
      String input = await file.readAsString();

      if (input.startsWith('\uFEFF')) {
        input = input.substring(1);
      }

      input = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(input);

      if (rows.isNotEmpty && rows.first.length <= 1) {
        rows = const CsvToListConverter(
          fieldDelimiter: ';',
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(input);
      }

      return rows;
    } catch (e) {
      debugPrint('Read CSV raw error: $e');
      return null;
    }
  }

  // ==========================================
  // ДОПОМІЖНІ МЕТОДИ ДЛЯ ЕКСПОРТУ
  // ==========================================

  static String _escapeCsv(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n')) {
      return '"${input.replaceAll('"', '""')}"';
    }
    return input;
  }

  static String _getTxType(Category? from, Category? to) {
    if (from == null || to == null) {
      return 'csv_type_other'.tr();
    }
    if (from.type == CategoryType.income && to.type == CategoryType.account) {
      return 'csv_type_income'.tr();
    }
    if (from.type == CategoryType.account && to.type == CategoryType.expense) {
      return 'csv_type_expense'.tr();
    }
    if (from.type == CategoryType.account && to.type == CategoryType.account) {
      return 'csv_type_transfer'.tr();
    }
    return 'csv_type_other'.tr();
  }

  static String _formatAmount(int amount) {
    return (amount / 100).toStringAsFixed(2);
  }

  // ==========================================
  // ПРОФЕСІЙНИЙ ЕКСПОРТ У CSV
  // ==========================================
  static Future<String> exportToCsv({
    required List<Transaction> transactions,
    required List<Category> allCategories,
  }) async {
    try {
      if (transactions.isEmpty) {
        return 'error';
      }

      final catMap = {for (var c in allCategories) c.id: c};

      final buffer = StringBuffer();
      buffer.write('\uFEFF');
      buffer.writeln('csv_export_headers'.tr());

      // Попередньо кешуємо системні рядки для порівняння
      final trOutgoing = 'outgoing_transfer'.tr();
      final trTopUp = 'top_up'.tr();

      for (var tx in transactions) {
        final fromCat = catMap[tx.fromId];
        final toCat = catMap[tx.toId];

        final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(tx.date);
        final txType = _getTxType(fromCat, toCat);

        final fromNameRaw = fromCat?.name ?? 'csv_deleted_category'.tr();
        final toNameRaw = toCat?.name ?? 'csv_deleted_category'.tr();

        final fromName = _escapeCsv(fromNameRaw);
        final toName = _escapeCsv(toNameRaw);

        final amountFrom = _formatAmount(tx.amount);
        final currencyFrom = tx.currency;

        final amountTo = _formatAmount(tx.targetAmount ?? tx.amount);
        final currencyTo = tx.targetCurrency ?? tx.currency;

        // 👇 НОВА ЛОГІКА ФІЛЬТРАЦІЇ КОМЕНТАРЯ
        final String rawTitle = tx.title.trim();

        final bool isDefaultTitle =
            rawTitle.isEmpty ||
            rawTitle.contains('➡️') ||
            rawTitle == fromNameRaw ||
            rawTitle == toNameRaw ||
            rawTitle == trOutgoing ||
            rawTitle == trTopUp;

        // Якщо заголовок системний — записуємо порожній рядок, інакше екрануємо коментар
        final comment = isDefaultTitle ? '' : _escapeCsv(rawTitle);

        buffer.writeln(
          '$dateStr,$txType,$fromName,$amountFrom,$currencyFrom,$toName,$amountTo,$currencyTo,$comment',
        );
      }

      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('dd_MM_yyyy_HHmm').format(DateTime.now());
      final path = '${directory.path}/LiteBalance_Export_$dateStr.csv';

      final file = File(path);
      await file.writeAsString(buffer.toString());

      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'my_coinflow_backup'.tr()),
      );

      try {
        if (await file.exists()) {
          await file.delete();
          debugPrint('✅ Тимчасовий CSV-файл успішно видалено з кешу');
        }
      } catch (e) {
        debugPrint('❌ Не вдалося видалити тимчасовий файл експорту: $e');
      }

      if (result.status == ShareResultStatus.success) {
        return 'success';
      } else if (result.status == ShareResultStatus.dismissed) {
        return 'dismissed';
      }
      return 'success';
    } catch (e) {
      debugPrint('Export error: $e');
      return 'error';
    }
  }

  @visibleForTesting
  static String generateCsvString({
    required List<Transaction> transactions,
    required List<Category> allCategories,
  }) {
    final catMap = {for (var c in allCategories) c.id: c};
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('csv_export_headers'.tr());

    final trOutgoing = 'outgoing_transfer'.tr();
    final trTopUp = 'top_up'.tr();

    for (var tx in transactions) {
      final fromCat = catMap[tx.fromId];
      final toCat = catMap[tx.toId];

      final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(tx.date);
      final txType = _getTxType(fromCat, toCat);
      final fromNameRaw = fromCat?.name ?? 'csv_deleted_category'.tr();
      final toNameRaw = toCat?.name ?? 'csv_deleted_category'.tr();

      final fromName = _escapeCsv(fromNameRaw);
      final toName = _escapeCsv(toNameRaw);
      final amountFrom = _formatAmount(tx.amount);
      final amountTo = _formatAmount(tx.targetAmount ?? tx.amount);

      final String rawTitle = tx.title.trim();
      final bool isDefaultTitle =
          rawTitle.isEmpty ||
          rawTitle.contains('➡️') ||
          rawTitle == fromNameRaw ||
          rawTitle == toNameRaw ||
          rawTitle == trOutgoing ||
          rawTitle == trTopUp;

      final comment = isDefaultTitle ? '' : _escapeCsv(rawTitle);

      buffer.writeln(
        '$dateStr,$txType,$fromName,$amountFrom,${tx.currency},$toName,$amountTo,${tx.targetCurrency ?? tx.currency},$comment',
      );
    }
    return buffer.toString();
  }
}
