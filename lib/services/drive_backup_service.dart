import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'package:coin_flow/database/app_database.dart';

enum SyncStatus { backedUp, restored, upToDate, error, noAuth }

class DriveBackupService {
  final GoogleAuthService _authService;

  // 👇 НОВЕ: Змінюємо розширення файлу в хмарі, щоб показати, що це GZip архів
  final String _backupFileName = 'coinflow_db.sqlite.gz';

  DriveBackupService(this._authService);

  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // Локальний файл залишається звичайним файлом SQLite (.sqlite)
    return File(p.join(dbFolder.path, 'coinflow_db.sqlite'));
  }

  // ОБГОРТКА З АВТО-ПОВТОРОМ
  Future<T> _executeWithRetry<T>(
    Future<T> Function(http.Client client) action, {
    required bool allowInteractive,
    required T fallbackValue,
  }) async {
    try {
      final client = await _authService.getAuthenticatedClient(
        allowInteractive: allowInteractive,
      );
      if (client == null) return fallbackValue;

      return await action(client);
    } catch (e) {
      final errorString = e.toString();

      if (errorString.contains('invalid_token') ||
          errorString.contains('Access was denied') ||
          errorString.contains('401')) {
        debugPrint(
          '[DriveBackup] ⚠️ Токен протух (знайдено invalid_token). Очищуємо...',
        );
        await _authService.clearTokenAndSignOut();

        if (allowInteractive) {
          debugPrint('[DriveBackup] 🔄 Повторна спроба (з UI)...');

          final retryClient = await _authService.getAuthenticatedClient(
            allowInteractive: true,
          );
          if (retryClient == null) return fallbackValue;

          try {
            return await action(retryClient);
          } catch (retryError) {
            log('Retry Error: $retryError', name: 'DriveBackup');
            return fallbackValue;
          }
        } else {
          debugPrint('[DriveBackup] 🚫 Фоновий режим. Скасовуємо повтор.');
          return fallbackValue;
        }
      }

      log('Unexpected Error: $e', name: 'DriveBackup');
      return fallbackValue;
    }
  }

  Future<bool> backupDatabase(
    AppDatabase db, {
    bool allowInteractive = true,
  }) async {
    return _executeWithRetry<bool>(
      (client) async {
        debugPrint('🧹 Виконання SQLite Checkpoint перед експортом...');
        await db.forceCheckpoint();

        final driveApi = drive.DriveApi(client);
        final localFile = await _getLocalDatabaseFile();

        if (!await localFile.exists()) return false;

        // 👇 КРОК 1: Стискаємо локальну базу даних за допомогою GZip
        debugPrint('📦 Стиснення бази даних (GZip)...');
        final originalBytes = await localFile.readAsBytes();
        final compressedBytes = gzip.encode(originalBytes);

        // Створюємо тимчасовий файл для завантаження
        final tempGzFile = File('${localFile.path}_upload.gz');
        await tempGzFile.writeAsBytes(compressedBytes);

        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
        );

        final existingFileId = fileList.files?.isNotEmpty == true
            ? fileList.files!.first.id
            : null;

        // Передаємо в стрим тимчасовий стиснутий файл
        final media = drive.Media(
          tempGzFile.openRead(),
          tempGzFile.lengthSync(),
        );

        if (existingFileId != null) {
          debugPrint('🔄 Оновлення архіву в хмарі (ID: $existingFileId)');
          await driveApi.files.update(
            drive.File(),
            existingFileId,
            uploadMedia: media,
          );
        } else {
          final driveFile = drive.File()
            ..name = _backupFileName
            ..parents = ['appDataFolder'];
          await driveApi.files.create(driveFile, uploadMedia: media);
        }

        // 👇 КРОК 2: Прибираємо за собою тимчасовий архів
        if (await tempGzFile.exists()) {
          await tempGzFile.delete();
        }

        debugPrint('✅ Стиснуту базу успішно завантажено в хмару');
        return true;
      },
      allowInteractive: allowInteractive,
      fallbackValue: false,
    );
  }

  Future<bool> restoreDatabase(
    AppDatabase db, {
    bool allowInteractive = true,
  }) async {
    return _executeWithRetry<bool>(
      (client) async {
        final driveApi = drive.DriveApi(client);

        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
          orderBy: 'modifiedTime desc',
        );

        if (fileList.files == null || fileList.files!.isEmpty) return false;

        final backupFile = fileList.files!.first;
        final drive.Media fileMedia =
            await driveApi.files.get(
                  backupFile.id!,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                )
                as drive.Media;

        final localFile = await _getLocalDatabaseFile();
        final dbPath = localFile.path;

        // 👇 КРОК 1: Завантажуємо спочатку у ТИМЧАСОВИЙ стиснутий архів
        debugPrint('📥 Завантаження стиснутого архіву з хмари...');
        final tempGzFile = File('${dbPath}_temp.gz');
        final fileStream = tempGzFile.openWrite();
        await fileMedia.stream.pipe(fileStream);
        await fileStream.flush();
        await fileStream.close();

        // 👇 КРОК 2: Розпаковуємо завантажений GZip архів
        debugPrint('📦 Розпакування бази даних...');
        final compressedBytes = await tempGzFile.readAsBytes();
        final decompressedBytes = gzip.decode(compressedBytes);

        final tempDbFile = File('${dbPath}_temp');
        await tempDbFile.writeAsBytes(decompressedBytes);

        // Видаляємо тимчасовий .gz файл, він більше не потрібен
        if (await tempGzFile.exists()) {
          await tempGzFile.delete();
        }

        // КРОК 3: Безпечно закриваємо з'єднання
        debugPrint('🔌 Закриття з\'єднання з базою...');
        await db.closeConnection();

        final walFile = File('$dbPath-wal');
        final shmFile = File('$dbPath-shm');
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();

        // КРОК 4: Блискавична підміна основного файлу розпакованими даними
        if (await localFile.exists()) await localFile.delete();
        await tempDbFile.copy(dbPath);
        await tempDbFile.delete();

        debugPrint('✅ Файл бази безпечно розпаковано та замінено');
        return true;
      },
      allowInteractive: allowInteractive,
      fallbackValue: false,
    );
  }

  Future<SyncStatus> performSmartSync(
    AppDatabase db,
    bool isLocalDirty, {
    bool allowInteractive = true,
  }) async {
    return _executeWithRetry<SyncStatus>(
      (client) async {
        final driveApi = drive.DriveApi(client);

        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
          $fields: 'files(id, modifiedTime)',
        );

        final cloudFile = fileList.files?.firstOrNull;
        final localFile = await _getLocalDatabaseFile();

        if (cloudFile == null) {
          debugPrint('☁️ Хмарний бекап не знайдено. Створюємо новий...');
          final success = await backupDatabase(db, allowInteractive: false);
          return success ? SyncStatus.backedUp : SyncStatus.error;
        }

        if (!await localFile.exists()) {
          debugPrint('📱 Локальної бази немає. Відновлюємо з хмари...');
          final success = await restoreDatabase(db, allowInteractive: false);
          return success ? SyncStatus.restored : SyncStatus.error;
        }

        final cloudTime = cloudFile.modifiedTime?.toUtc();
        await db.forceCheckpoint();
        final localTime = localFile.lastModifiedSync().toUtc();

        debugPrint('🕒 Час локальної бази: $localTime');
        debugPrint('🕒 Час хмарної бази: $cloudTime');
        debugPrint('🚩 isLocalDirty: $isLocalDirty');

        if (isLocalDirty ||
            (cloudTime != null && localTime.isAfter(cloudTime))) {
          debugPrint('⬆️ Локальна база новіша. Перезаписуємо хмару...');
          final success = await backupDatabase(db, allowInteractive: false);
          return success ? SyncStatus.backedUp : SyncStatus.error;
        } else if (cloudTime != null && cloudTime.isAfter(localTime)) {
          debugPrint('⬇️ Хмарна база новіша. Перезаписуємо локальну...');
          final success = await restoreDatabase(db, allowInteractive: false);
          return success ? SyncStatus.restored : SyncStatus.error;
        }

        debugPrint('✅ Бази синхронізовані (однаковий час).');
        return SyncStatus.upToDate;
      },
      allowInteractive: allowInteractive,
      fallbackValue: SyncStatus.error,
    );
  }
}
