import 'dart:async';
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
  // 👇 Запобіжник: блокує подвійний запуск
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
    // 👇 ДОДАНО inactive: Ловимо подію ДО того, як ОС повністю заморозить додаток.
    // Оскільки у нас є запобіжник _isAutoSyncing, подвійного запуску не буде:
    // inactive заблокує процес, а наступні paused/hidden просто проігноруються.
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

      // Якщо немає мережі взагалі (новий API ConnectivityPlus повертає список)
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      final settings = ref.read(settingsProvider);

      // Якщо вимагається тільки Wi-Fi
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
    // 👇 1. Запобіжник перевіряємо і миттєво блокуємо ДО всіх await!
    if (_isAutoSyncing) return;
    _isAutoSyncing = true;

    try {
      final isDirty = ref.read(dbDirtyProvider);
      final settings = ref.read(settingsProvider);
      final prefs = ref.read(sharedPreferencesProvider);

      final hasLoggedIn = prefs.getBool('has_logged_in_with_google') ?? false;
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;

      // 👇 ФІКС: Жодної фонової синхронізації, поки користувач на екрані онбордингу!
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
            _isAutoSyncing = false; // Знімаємо блок
            return;
          }
        }
      } else {
        if (!isDirty) {
          _isAutoSyncing = false; // Знімаємо блок
          return;
        }
      }

      if (!await _canSyncNow()) {
        debugPrint('📶 Пропуск авто-синхронізації: відсутня потрібна мережа');
        _isAutoSyncing = false; // Знімаємо блок
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
            _isAutoSyncing = false; // Гарантовано знімаємо блок в кінці
          }
        }),
      );
    } catch (e) {
      debugPrint('Помилка авто-синхронізації: $e');
      _isAutoSyncing = false; // Знімаємо блок при помилці
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
