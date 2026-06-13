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
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../database/app_database.dart';
import '../utils/app_lock.dart';
import 'storage_service.dart';

class BackupService {
  /// Тег нового формату бекапу. Рядок файлу:
  /// `LBK2:<iterations>:<saltB64>:<ivB64>:<cipherB64>`.
  static const String _v2Tag = 'LBK2';
  static const int _pbkdf2Iterations = 120000;

  /// Старий вивід ключа (SHA-256 від пароля без солі). Лишаємо ВИКЛЮЧНО для
  /// розшифрування раніше створених `.cfbak` — нові бекапи його не пишуть.
  static enc.Key _generateKeyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Вивід ключа через PBKDF2-HMAC-SHA256 (сіль + ітерації) — стійко до підбору.
  static enc.Key _deriveKey(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return enc.Key(derivator.process(Uint8List.fromList(utf8.encode(password))));
  }

  static String _buildPayloadJson(
    List<Category> categories,
    List<Transaction> transactions,
    List<Subscription> subscriptions,
  ) {
    return jsonEncode(<String, dynamic>{
      'version': 1,
      'categories': categories.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    });
  }

  /// Шифрує JSON у новий формат [_v2Tag] (PBKDF2 + випадкова сіль + випадковий IV).
  static String _encryptPayload(String password, String jsonString) {
    final salt = enc.IV.fromSecureRandom(16).bytes;
    final key = _deriveKey(password, salt, _pbkdf2Iterations);
    final encrypter = enc.Encrypter(enc.AES(key));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    return '$_v2Tag:$_pbkdf2Iterations:${base64.encode(salt)}:${iv.base64}:${encrypted.base64}';
  }

  /// Розшифровує вміст бекапу, автоматично визначаючи формат:
  /// новий [_v2Tag] (PBKDF2), старий `iv:cipher` (SHA-256) та legacy (нульовий IV).
  static String _decryptToJson(String password, String content) {
    final t = content.trim();

    if (t.startsWith('$_v2Tag:')) {
      final p = t.split(':'); // LBK2 : iters : salt : iv : cipher
      final iterations = int.parse(p[1]);
      final salt = Uint8List.fromList(base64.decode(p[2]));
      final key = _deriveKey(password, salt, iterations);
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt64(p[4], iv: enc.IV.fromBase64(p[3]));
    }

    // Старі формати: ключ = SHA-256(пароль).
    final key = _generateKeyFromPassword(password);
    final encrypter = enc.Encrypter(enc.AES(key));
    if (t.contains(':')) {
      final p = t.split(':');
      return encrypter.decrypt64(p[1], iv: enc.IV.fromBase64(p[0]));
    }
    return encrypter.decrypt64(t, iv: enc.IV.fromLength(16));
  }

  static Future<void> exportData(
    String password,
    List<Category> categories,
    List<Transaction> transactions,
    List<Subscription> subscriptions,
  ) async {
    try {
      debugPrint('📦 Початок експорту даних...');
      final String jsonString = _buildPayloadJson(
        categories,
        transactions,
        subscriptions,
      );
      final exportString = _encryptPayload(password, jsonString);

      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('dd_MM_yyyy_HHmm').format(DateTime.now());
      final file = File('${directory.path}/litebalance_backup_$dateStr.cfbak');

      await file.writeAsString(exportString);

      final params = ShareParams(
        text: 'backup_share_text'.tr(),
        files: [XFile(file.path)],
      );

      await AppLock.runTrusted(() => SharePlus.instance.share(params));

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
      final result = await AppLock.runTrusted(
        () => FilePicker.platform.pickFiles(type: FileType.any),
      );

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
          jsonString = _decryptToJson(password, fileContent);
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
    return _encryptPayload(
      password,
      _buildPayloadJson(categories, transactions, subscriptions),
    );
  }

  @visibleForTesting
  static Map<String, dynamic> decryptPayload(
    String password,
    String fileContent,
  ) {
    final jsonString = _decryptToJson(password, fileContent);
    final dynamic decoded = jsonDecode(jsonString);
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Старе шифрування (SHA-256, без солі) — лише для тестів зворотної сумісності.
  @visibleForTesting
  static String legacyEncryptedPayload(
    String password,
    List<Category> categories,
    List<Transaction> transactions,
    List<Subscription> subscriptions,
  ) {
    final jsonString = _buildPayloadJson(categories, transactions, subscriptions);
    final key = _generateKeyFromPassword(password);
    final encrypter = enc.Encrypter(enc.AES(key));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }
}
