import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';
import 'package:litebalance/database/app_database.dart';

enum SyncStatus { backedUp, restored, upToDate, error, noAuth }

/// Інформація про одну копію в хмарі (актуальна або датований знімок-історія).
class CloudBackupInfo {
  final String id;
  final DateTime? date;
  final int sizeBytes;
  final bool isCurrent;

  CloudBackupInfo({
    required this.id,
    required this.date,
    required this.sizeBytes,
    required this.isCurrent,
  });
}

class DriveBackupService {
  final GoogleAuthService _authService;

  // Актуальна (жива) копія, яку перезаписує синхронізація.
  final String _backupFileName = 'coinflow_db.sqlite.gz';

  // Префікс датованих знімків-історії (для відкату).
  static const String _snapshotPrefix = 'lb_snapshot_';
  static const int _maxSnapshots = 5; // тримаємо останні 5 щоденних знімків

  DriveBackupService(this._authService);

  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
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

  String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  DateTime? _parseSnapshotDate(String? name) {
    if (name == null) return null;
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(name);
    if (match == null) return null;
    return DateTime.tryParse(
      '${match.group(1)}-${match.group(2)}-${match.group(3)}',
    );
  }

  /// Раз на день архівує поточну (живу) копію в датований знімок ПЕРЕД тим,
  /// як її перезапише нова синхронізація. Тримає останні [_maxSnapshots].
  /// Помилка тут не блокує сам бекап.
  Future<void> _ensureDailySnapshot(
    drive.DriveApi driveApi,
    String mainFileId,
  ) async {
    try {
      final snapName = '$_snapshotPrefix${_todayKey()}.sqlite.gz';

      final existing = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$snapName' and trashed = false",
      );
      if (existing.files != null && existing.files!.isNotEmpty) {
        return; // знімок за сьогодні вже є
      }

      // Серверна копія живого файлу у датований знімок (без завантаження).
      await driveApi.files.copy(
        drive.File()
          ..name = snapName
          ..parents = ['appDataFolder'],
        mainFileId,
      );

      await _pruneSnapshots(driveApi);
    } catch (e) {
      debugPrint('[DriveBackup] Пропуск щоденного знімка: $e');
    }
  }

  Future<void> _pruneSnapshots(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name contains '$_snapshotPrefix' and trashed = false",
      $fields: 'files(id, name)',
    );
    final files = list.files ?? <drive.File>[];
    if (files.length <= _maxSnapshots) return;

    // Найновіші за назвою (дата) — першими.
    files.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
    for (final f in files.skip(_maxSnapshots)) {
      if (f.id != null) {
        try {
          await driveApi.files.delete(f.id!);
        } catch (_) {}
      }
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

        debugPrint('📦 Стиснення бази даних (GZip)...');
        final originalBytes = await localFile.readAsBytes();
        final compressedBytes = gzip.encode(originalBytes);

        final tempGzFile = File('${localFile.path}_upload.gz');
        await tempGzFile.writeAsBytes(compressedBytes);

        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
        );

        final existingFileId = fileList.files != null && fileList.files!.isNotEmpty
            ? fileList.files!.first.id
            : null;

        // 👇 Перед перезаписом живої копії — щоденний знімок-історія для відкату.
        if (existingFileId != null) {
          await _ensureDailySnapshot(driveApi, existingFileId);
        }

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

  /// Завантажує файл [fileId] з хмари, розпаковує й безпечно підміняє локальну
  /// базу. Перед підміною робить резервну копію старого файлу (атомарність).
  Future<bool> _downloadDecompressSwap(
    drive.DriveApi driveApi,
    String fileId,
    AppDatabase db,
  ) async {
    final localFile = await _getLocalDatabaseFile();
    final dbPath = localFile.path;

    final drive.Media fileMedia =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    debugPrint('📥 Завантаження стиснутого архіву з хмари...');
    final tempGzFile = File('${dbPath}_temp.gz');
    final fileStream = tempGzFile.openWrite();
    await fileMedia.stream.pipe(fileStream);
    await fileStream.flush();
    await fileStream.close();

    debugPrint('📦 Розпакування бази даних...');
    final compressedBytes = await tempGzFile.readAsBytes();
    final decompressedBytes = gzip.decode(compressedBytes);

    final tempDbFile = File('${dbPath}_temp');
    await tempDbFile.writeAsBytes(decompressedBytes);

    if (await tempGzFile.exists()) {
      await tempGzFile.delete();
    }

    debugPrint('🔌 Закриття з\'єднання з базою...');
    await db.closeConnection();

    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    // 👇 Атомарність: зберігаємо старий файл, поки не переконаємось в успіху.
    final rollbackFile = File('${dbPath}_rollback');
    if (await localFile.exists()) {
      if (await rollbackFile.exists()) await rollbackFile.delete();
      await localFile.rename(rollbackFile.path);
    }

    try {
      await tempDbFile.copy(dbPath);
      await tempDbFile.delete();
      if (await rollbackFile.exists()) await rollbackFile.delete();
      debugPrint('✅ Файл бази безпечно розпаковано та замінено');
      return true;
    } catch (e) {
      // Відкочуємось до старого файлу, якщо підміна не вдалась.
      debugPrint('❌ Помилка підміни бази, відкат: $e');
      if (await rollbackFile.exists()) {
        if (await localFile.exists()) await localFile.delete();
        await rollbackFile.rename(dbPath);
      }
      return false;
    }
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

        return _downloadDecompressSwap(
          driveApi,
          fileList.files!.first.id!,
          db,
        );
      },
      allowInteractive: allowInteractive,
      fallbackValue: false,
    );
  }

  /// Відновлення з конкретної копії (актуальної або датованого знімка).
  Future<bool> restoreFromId(
    AppDatabase db,
    String fileId, {
    bool allowInteractive = true,
  }) async {
    return _executeWithRetry<bool>(
      (client) async {
        final driveApi = drive.DriveApi(client);
        return _downloadDecompressSwap(driveApi, fileId, db);
      },
      allowInteractive: allowInteractive,
      fallbackValue: false,
    );
  }

  /// Список доступних копій у хмарі: актуальна + датовані знімки (новіші перші).
  Future<List<CloudBackupInfo>> listCloudBackups({
    bool allowInteractive = true,
  }) async {
    return _executeWithRetry<List<CloudBackupInfo>>(
      (client) async {
        final driveApi = drive.DriveApi(client);
        final result = <CloudBackupInfo>[];

        final mainList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_backupFileName' and trashed = false",
          $fields: 'files(id, modifiedTime, size)',
        );
        if (mainList.files != null && mainList.files!.isNotEmpty) {
          final m = mainList.files!.first;
          if (m.id != null) {
            result.add(
              CloudBackupInfo(
                id: m.id!,
                date: m.modifiedTime?.toLocal(),
                sizeBytes: int.tryParse(m.size ?? '') ?? 0,
                isCurrent: true,
              ),
            );
          }
        }

        final snapList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name contains '$_snapshotPrefix' and trashed = false",
          $fields: 'files(id, name, modifiedTime, size)',
        );
        for (final f in (snapList.files ?? <drive.File>[])) {
          if (f.id == null) continue;
          result.add(
            CloudBackupInfo(
              id: f.id!,
              date: _parseSnapshotDate(f.name) ?? f.modifiedTime?.toLocal(),
              sizeBytes: int.tryParse(f.size ?? '') ?? 0,
              isCurrent: false,
            ),
          );
        }

        result.sort(
          (a, b) =>
              (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)),
        );
        return result;
      },
      allowInteractive: allowInteractive,
      fallbackValue: <CloudBackupInfo>[],
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

        final cloudFile =
            fileList.files != null && fileList.files!.isNotEmpty
            ? fileList.files!.first
            : null;
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
