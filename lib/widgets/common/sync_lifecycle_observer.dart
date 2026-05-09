import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/all_providers.dart';

class SyncLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const SyncLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Спроба бекапу при згортанні (може бути перервана системою)
      _attemptAutoBackup();
    } else if (state == AppLifecycleState.resumed) {
      // 👇 СТРАХОВКА: Якщо бекап не вдався, робимо його при поверненні в додаток!
      _attemptAutoBackup();
    }
  }

  // 👇 ХЕЛПЕР ДЛЯ ПЕРЕВІРКИ МЕРЕЖІ
  Future<bool> _canSyncNow() async {
    final settings = ref.read(settingsProvider);
    if (!settings.syncOnlyViaWifi) {
      return true; // Якщо дозволено будь-який інтернет - пускаємо
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      // Перевіряємо, чи є серед підключень Wi-Fi
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      return false; // Якщо помилка - краще не синхронізувати, щоб не спалити трафік
    }
  }

  Future<void> _attemptAutoBackup() async {
    final isDirty = ref.read(dbDirtyProvider);
    if (!isDirty) return;

    final account = ref.read(authControllerProvider).value;
    if (account == null) return;

    if (!await _canSyncNow()) return; // Скасовуємо, якщо немає Wi-Fi

    try {
      final db = ref.read(appDatabaseProvider);
      final driveService = ref.read(driveBackupServiceProvider);

      final success = await driveService.backupDatabase(db);
      if (success) {
        ref.read(dbDirtyProvider.notifier).setDirty(false);
        // Фіксуємо час успішної синхронізації
        await ref.read(settingsProvider.notifier).updateCloudBackupTime();
      }
    } catch (e) {
      debugPrint('❌ Помилка авто-бекапу: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
