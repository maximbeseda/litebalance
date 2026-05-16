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
    if (state == AppLifecycleState.paused ||
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
    if (_isAutoSyncing) return;

    final isDirty = ref.read(dbDirtyProvider);
    final settings = ref.read(settingsProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // 👇 Перевіряємо, чи юзер ВЗАГАЛІ логінився. Якщо ні - ігноруємо.
    final hasLoggedIn = prefs.getBool('has_logged_in_with_google') ?? false;
    if (!hasLoggedIn) return;

    // 👇 ТОП-ПРАКТИКА: Оптимізація запитів до сервера
    if (state == AppLifecycleState.resumed) {
      if (!isDirty && settings.lastCloudBackup != null) {
        final difference = DateTime.now().difference(settings.lastCloudBackup!);
        if (difference.inMinutes < 10) {
          debugPrint(
            '⏳ Пропуск авто-синхронізації: з останньої пройшло менше 10 хв',
          );
          return;
        }
      }
    } else {
      if (!isDirty) return;
    }

    if (!await _canSyncNow()) {
      debugPrint('📶 Пропуск авто-синхронізації: відсутня потрібна мережа');
      return;
    }

    _isAutoSyncing = true;
    try {
      debugPrint('🔄 Запуск фонової синхронізації (State: $state)...');

      // 👇 Вказуємо, що це АВТОМАТИЧНИЙ виклик!
      await ref.read(syncControllerProvider.notifier).syncNow(isAuto: true);
    } catch (e) {
      debugPrint('❌ Критична помилка фонової синхронізації: $e');
    } finally {
      _isAutoSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
