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
  final String _backupFileName = 'coinflow_db.sqlite';

  DriveBackupService(this._authService);

  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, _backupFileName));
  }

  // 👇 НОВА ЧАРІВНА ОБГОРТКА
  // Вона приймає функцію, виконує її, і якщо ловить 401 - стирає токен і повторює знову
  Future<T> _executeWithRetry<T>(
    Future<T> Function(http.Client client) action, {
    required bool allowInteractive,
    required T fallbackValue,
  }) async {
    try {
      // ФІКС 1: Робимо змінну final
      final client = await _authService.getAuthenticatedClient(
        allowInteractive: allowInteractive,
      );
      if (client == null) return fallbackValue;

      // Виконуємо основну дію
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

          // 👇 ФІКС 2: Створюємо НОВУ змінну retryClient, бо старий client тут недоступний
          final retryClient = await _authService.getAuthenticatedClient(
            allowInteractive: true,
          );
          if (retryClient == null) return fallbackValue;

          try {
            // Повторюємо дію з новим клієнтом
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

      // Якщо це дійсно якась інша помилка
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

        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
        );

        final existingFileId = fileList.files?.isNotEmpty == true
            ? fileList.files!.first.id
            : null;

        final media = drive.Media(localFile.openRead(), localFile.lengthSync());

        if (existingFileId != null) {
          debugPrint('🔄 Оновлення файлу в хмарі (ID: $existingFileId)');
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

        final tempFile = File('${dbPath}_temp');
        final fileStream = tempFile.openWrite();
        await fileMedia.stream.pipe(fileStream);
        await fileStream.flush();
        await fileStream.close();

        debugPrint('🔌 Закриття з\'єднання з базою...');
        await db.closeConnection();

        final walFile = File('$dbPath-wal');
        final shmFile = File('$dbPath-shm');
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();

        if (await localFile.exists()) await localFile.delete();
        await tempFile.copy(dbPath);
        await tempFile.delete();

        debugPrint('✅ Файл бази безпечно замінено');
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
          // Викликаємо backupDatabase і передаємо false, бо ми вже в обгортці і самі обробимо помилку, якщо що.
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
