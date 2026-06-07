import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import 'storage_service.dart';

class BackupService {
  static enc.Key _generateKeyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  static Future<void> exportData(
    String password,
    List<Category> categories,
    List<Transaction> transactions,
    List<Subscription> subscriptions,
  ) async {
    try {
      debugPrint('📦 Початок експорту даних...');
      final data = <String, dynamic>{
        'version': 1,
        'categories': categories.map((c) => c.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
      };

      final String jsonString = jsonEncode(data);
      final key = _generateKeyFromPassword(password);
      final encrypter = enc.Encrypter(enc.AES(key));

      final iv = enc.IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      final exportString = '${iv.base64}:${encrypted.base64}';

      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('dd_MM_yyyy_HHmm').format(DateTime.now());
      final file = File('${directory.path}/litebalance_backup_$dateStr.cfbak');

      await file.writeAsString(exportString);

      final params = ShareParams(
        text: 'backup_share_text'.tr(),
        files: [XFile(file.path)],
      );

      await SharePlus.instance.share(params);

      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Тимчасовий файл бекапу успішно видалено');
      }
    } catch (e) {
      debugPrint('❌ Помилка експорту: $e');
      throw Exception('backup_error'.tr());
    }
  }

  // 👇 НОВИЙ МЕТОД: Крок 1 — Вибір файлу
  static Future<File?> pickBackupFile() async {
    try {
      debugPrint('📂 Відкриття вибору файлу...');
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty) {
        debugPrint('ℹ️ Вибір файлу скасовано');
        return null;
      }

      final path = result.files.single.path;
      return path != null ? File(path) : null;
    } catch (e) {
      debugPrint('❌ Помилка при виборі файлу: $e');
      return null;
    }
  }

  // 👇 НОВИЙ МЕТОД: Крок 2 — Імпорт з уже обраного файлу
  static Future<void> importDataFromFile(
    File file,
    String password,
    AppDatabase db,
  ) async {
    try {
      final String fileContent = await file.readAsString();
      final String fileName = file.path.toLowerCase();
      String jsonString;

      if (fileName.endsWith('.cfbak')) {
        debugPrint('🔐 Розшифрування файлу .cfbak...');
        try {
          final key = _generateKeyFromPassword(password);
          final encrypter = enc.Encrypter(enc.AES(key));
          final trimmedContent = fileContent.trim();

          if (trimmedContent.contains(':')) {
            final parts = trimmedContent.split(':');
            final iv = enc.IV.fromBase64(parts[0]);
            final encryptedBase64 = parts[1];
            jsonString = encrypter.decrypt64(encryptedBase64, iv: iv);
          } else {
            final legacyIv = enc.IV.fromLength(16);
            jsonString = encrypter.decrypt64(trimmedContent, iv: legacyIv);
          }
        } catch (e) {
          throw Exception('wrong_password_or_corrupted'.tr());
        }
      } else if (fileName.endsWith('.json')) {
        jsonString = fileContent;
      } else {
        throw Exception('invalid_backup_format'.tr());
      }

      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('corrupted_backup'.tr());
      }

      debugPrint('🛠 Мапінг об\'єктів...');

      final List<Category> importedCategories =
          (decoded['categories'] as List? ?? [])
              .map(
                (e) => Category.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();

      final List<Transaction> importedTransactions =
          (decoded['transactions'] as List? ?? [])
              .map(
                (e) =>
                    Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();

      final List<Subscription> importedSubscriptions =
          (decoded['subscriptions'] as List? ?? [])
              .map(
                (e) =>
                    Subscription.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();

      debugPrint('💾 Запис у базу даних...');
      await db.transaction(() async {
        await StorageService.wipeEntireDatabase(db);
        await StorageService.saveCategories(db, importedCategories);
        await StorageService.saveHistory(db, importedTransactions);
        for (final sub in importedSubscriptions) {
          await StorageService.saveSubscription(db, sub);
        }
      });

      debugPrint('✅ Імпорт завершено');
    } catch (e) {
      debugPrint('❌ Помилка імпорту: $e');
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('import_error'.tr());
    } finally {
      await FilePicker.platform.clearTemporaryFiles();
    }
  }

  // Залишаємо старий метод для зворотної сумісності (якщо десь використовується)
  // або можеш його видалити, якщо перейшов на нову логіку всюди
  static Future<void> importData(String password, AppDatabase db) async {
    final file = await pickBackupFile();
    if (file != null) {
      await importDataFromFile(file, password, db);
    }
  }

  @visibleForTesting
  static String generateEncryptedPayload(
    String password,
    List<Category> categories,
    List<Transaction> transactions,
    List<Subscription> subscriptions,
  ) {
    final data = <String, dynamic>{
      'version': 1,
      'categories': categories.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    };

    final String jsonString = jsonEncode(data);
    final key = _generateKeyFromPassword(password);
    final encrypter = enc.Encrypter(enc.AES(key));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }

  @visibleForTesting
  static Map<String, dynamic> decryptPayload(
    String password,
    String fileContent,
  ) {
    final key = _generateKeyFromPassword(password);
    final encrypter = enc.Encrypter(enc.AES(key));
    final trimmedContent = fileContent.trim();
    String jsonString;

    if (trimmedContent.contains(':')) {
      final parts = trimmedContent.split(':');
      final iv = enc.IV.fromBase64(parts[0]);
      final encryptedBase64 = parts[1];
      jsonString = encrypter.decrypt64(encryptedBase64, iv: iv);
    } else {
      final legacyIv = enc.IV.fromLength(16);
      jsonString = encrypter.decrypt64(trimmedContent, iv: legacyIv);
    }

    final dynamic decoded = jsonDecode(jsonString);
    return Map<String, dynamic>.from(decoded as Map);
  }
}
