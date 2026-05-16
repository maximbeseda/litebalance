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

      final result = await backupService.performSmartSync(
        db,
        isLocalDirty,
        allowInteractive: !isAuto,
      );

      if (result == SyncStatus.error || result == SyncStatus.noAuth) {
        state = state.copyWith(isSyncing: false, hasError: true);
      } else {
        if (result == SyncStatus.restored) {
          debugPrint('🔄 База була відновлена! Перевідкриваємо з\'єднання...');
          ref.invalidate(appDatabaseProvider);
        }

        // 👇 ГРАНД-ФІКС 2: Спочатку залізобетонно оновлюємо всі метадані в системі,
        // поки прапорець isSyncing ще дорівнює true!
        await ref.read(settingsProvider.notifier).updateCloudBackupTime();
        ref.read(dbDirtyProvider.notifier).setDirty(false);

        // 👇 ТЕПЕР БЕЗПЕЧНО ЗНІМАЄМО ПРАПОРЕЦЬ.
        // Будь-який наступний випадковий запит побачить, що бази синхронні, і нічого не закриє.
        state = state.copyWith(isSyncing: false, hasError: false);

        // 👇 НАПРИКІНЦІ робимо тихе оновлення інтерфейсу
        try {
          await ref.read(transactionProvider.notifier).loadHistory();
          await ref.read(categoryProvider.notifier).loadCategories();
          await ref.read(subscriptionProvider.notifier).loadSubscriptions();
        } catch (e) {
          debugPrint('Помилка тихого оновлення провайдерів: $e');
        }
      }
    } catch (e) {
      debugPrint('SyncError: $e');
      state = state.copyWith(isSyncing: false, hasError: true);
    }
  }
}
