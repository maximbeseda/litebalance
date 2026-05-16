import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/google_auth_service.dart';
import '../services/drive_backup_service.dart';

import 'all_providers.dart';

part 'backup_providers.g.dart';

@Riverpod(keepAlive: true)
GoogleAuthService googleAuthService(Ref ref) {
  return GoogleAuthService();
}

@Riverpod(keepAlive: true)
DriveBackupService driveBackupService(Ref ref) {
  final auth = ref.watch(googleAuthServiceProvider);
  return DriveBackupService(auth);
}

// --- НОВИЙ СТАН СИНХРОНІЗАЦІЇ ---

class SyncState {
  final bool isSyncing;
  final bool hasError;

  const SyncState({this.isSyncing = false, this.hasError = false});

  SyncState copyWith({bool? isSyncing, bool? hasError}) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      hasError: hasError ?? this.hasError,
    );
  }
}

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  SyncState build() {
    return const SyncState(); // Початковий стан: не синхронізується, без помилок
  }

  Future<void> syncNow({bool isAuto = false}) async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, hasError: false);

    try {
      final db = ref.read(appDatabaseProvider);
      final backupService = ref.read(driveBackupServiceProvider);
      final isLocalDirty = ref.read(dbDirtyProvider);

      // 👇 Якщо це АВТО (isAuto = true), то інтерактив ЗАБОРОНЕНО (allowInteractive = false)
      final result = await backupService.performSmartSync(
        db,
        isLocalDirty,
        allowInteractive: !isAuto,
      );

      if (result == SyncStatus.error || result == SyncStatus.noAuth) {
        state = state.copyWith(isSyncing: false, hasError: true);
      } else {
        // 👇 ДОДАНО: Якщо ми завантажили базу з хмари, треба її "перезавантажити"
        if (result == SyncStatus.restored) {
          debugPrint(
            '🔄 База була відновлена! Перевідкриваємо з\'єднання та оновлюємо UI...',
          );

          // Змушуємо Riverpod створити нове підключення до бази
          ref.invalidate(appDatabaseProvider);

          // Очищаємо кеші екранів, щоб вони завантажили нові дані
          ref.invalidate(transactionProvider);
          ref.invalidate(categoryProvider);
          ref.invalidate(subscriptionProvider);
          ref.invalidate(statsProvider);
        }

        // Оновлюємо дату та скидаємо "брудні" дані
        await ref.read(settingsProvider.notifier).updateCloudBackupTime();
        ref.read(dbDirtyProvider.notifier).setDirty(false);

        state = state.copyWith(isSyncing: false, hasError: false);
      }
    } catch (e) {
      debugPrint('SyncError: $e');
      state = state.copyWith(isSyncing: false, hasError: true);
    }
  }
}
