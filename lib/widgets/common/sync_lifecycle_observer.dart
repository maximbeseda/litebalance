import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/all_providers.dart';

/// Спостерігач життєвого циклу для фонової авто-синхронізації з Google Drive.
/// (Блокування/шторку винесено в [AppLockGate].)
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;

  const SyncLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  bool _isAutoSyncing = false;

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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.resumed) {
      _attemptAutoSync(state);
    }
  }

  Future<bool> _canSyncNow() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      final settings = ref.read(settingsProvider);

      if (settings.syncOnlyViaWifi) {
        return connectivityResult.contains(ConnectivityResult.wifi) ||
            connectivityResult.contains(ConnectivityResult.ethernet);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _attemptAutoSync(AppLifecycleState state) async {
    if (_isAutoSyncing) return;
    _isAutoSyncing = true;

    try {
      final isDirty = ref.read(dbDirtyProvider);
      final settings = ref.read(settingsProvider);
      final prefs = ref.read(sharedPreferencesProvider);

      final hasLoggedIn = prefs.getBool('has_logged_in_with_google') ?? false;
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;

      if (!hasLoggedIn || !hasCompletedOnboarding) {
        _isAutoSyncing = false;
        return;
      }

      if (state == AppLifecycleState.resumed) {
        if (!isDirty && settings.lastCloudBackup != null) {
          final difference = DateTime.now().difference(
            settings.lastCloudBackup!,
          );
          if (difference.inMinutes < 10) {
            debugPrint('⏳ Пропуск авто-синхронізації: пройшло менше 10 хв');
            _isAutoSyncing = false;
            return;
          }
        }
      } else {
        if (!isDirty) {
          _isAutoSyncing = false;
          return;
        }
      }

      if (!await _canSyncNow()) {
        debugPrint('📶 Пропуск авто-синхронізації: відсутня потрібна мережа');
        _isAutoSyncing = false;
        return;
      }

      debugPrint('🔄 Запуск фонової синхронізації (State: $state)...');
      final syncNotifier = ref.read(syncControllerProvider.notifier);

      unawaited(
        Future.microtask(() async {
          try {
            await syncNotifier.syncNow(isAuto: true);
          } catch (e) {
            debugPrint('Помилка у фоновій синхронізації: $e');
          } finally {
            _isAutoSyncing = false;
          }
        }),
      );
    } catch (e) {
      debugPrint('Помилка авто-синхронізації: $e');
      _isAutoSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
