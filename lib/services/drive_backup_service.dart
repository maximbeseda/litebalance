import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'google_auth_service.dart';
import '../database/app_database.dart';

enum SyncStatus { backedUp, restored, upToDate, error, noAuth }

class DriveBackupService {
  final GoogleAuthService _authService;
  final String _backupFileName = 'coinflow_db.sqlite';

  DriveBackupService(this._authService);

  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, _backupFileName));
  }

  // 👇 ДОДАНО ПАРАМЕТР db ДЛЯ ЧЕКПОЇНТУ
  Future<bool> backupDatabase(AppDatabase db) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return false;

      // КРОК 0: Примусово зливаємо всі зміни в основний файл
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
    } catch (e) {
      log('Drive Backup Error: $e', name: 'DriveBackup');
      return false;
    }
  }

  Future<bool> restoreDatabase(AppDatabase db) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return false;

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

      // КРОК 1: Завантажуємо в ТИМЧАСОВИЙ файл
      final tempFile = File('${dbPath}_temp');
      final fileStream = tempFile.openWrite();
      await fileMedia.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      // КРОК 2: Тільки тепер закриваємо базу
      debugPrint('🔌 Закриття з\'єднання з базою...');
      await db.closeConnection();

      // КРОК 3: Видаляємо кеші SQLite
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // КРОК 4: Блискавична підміна файлу (безпечно для ОС)
      if (await localFile.exists()) await localFile.delete();
      await tempFile.copy(dbPath);
      await tempFile.delete();

      debugPrint('✅ Файл бази безпечно замінено');
      return true;
    } catch (e) {
      log('Drive Restore Error: $e', name: 'DriveBackup');
      return false;
    }
  }

  // 👇 НОВИЙ МЕТОД: Розумна синхронізація (Last Write Wins)
  Future<SyncStatus> performSmartSync(AppDatabase db, bool isLocalDirty) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) return SyncStatus.noAuth;

      final driveApi = drive.DriveApi(client);

      // Обов'язково просимо повернути modifiedTime (за замовчуванням Google його не віддає)
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, modifiedTime)',
      );

      final cloudFile = fileList.files?.firstOrNull;
      final localFile = await _getLocalDatabaseFile();

      // 1. Хмарного бекапу ще немає -> створюємо його
      if (cloudFile == null) {
        debugPrint('☁️ Хмарний бекап не знайдено. Створюємо новий...');
        final success = await backupDatabase(db);
        return success ? SyncStatus.backedUp : SyncStatus.error;
      }

      // 2. Локальної бази немає (наприклад, щойно встановили додаток) -> відновлюємо
      if (!await localFile.exists()) {
        debugPrint('📱 Локальної бази немає. Відновлюємо з хмари...');
        final success = await restoreDatabase(db);
        return success ? SyncStatus.restored : SyncStatus.error;
      }

      // 3. Порівнюємо дати (Обидва в UTC для точності)
      final cloudTime = cloudFile.modifiedTime?.toUtc();

      // Робимо чекпоїнт, щоб SQLite скинув дані з кешу (WAL) у файл, інакше час буде неточним
      await db.forceCheckpoint();
      final localTime = localFile.lastModifiedSync().toUtc();

      debugPrint('🕒 Час локальної бази: $localTime');
      debugPrint('🕒 Час хмарної бази: $cloudTime');
      debugPrint('🚩 isLocalDirty: $isLocalDirty');

      // Логіка "Last Write Wins"
      if (isLocalDirty || (cloudTime != null && localTime.isAfter(cloudTime))) {
        debugPrint('⬆️ Локальна база новіша. Перезаписуємо хмару...');
        final success = await backupDatabase(db);
        return success ? SyncStatus.backedUp : SyncStatus.error;
      } else if (cloudTime != null && cloudTime.isAfter(localTime)) {
        debugPrint('⬇️ Хмарна база новіша. Перезаписуємо локальну...');
        final success = await restoreDatabase(db);
        return success ? SyncStatus.restored : SyncStatus.error;
      }

      debugPrint('✅ Бази синхронізовані (однаковий час).');
      return SyncStatus.upToDate;
    } catch (e) {
      log('Smart Sync Error: $e', name: 'DriveBackup');
      return SyncStatus.error;
    }
  }
}
