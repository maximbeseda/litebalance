import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/all_providers.dart';
import '../../screens/lock_screen.dart';
import '../../utils/app_lock.dart';

// Публічні константи автоблокування (використовуються тут і в main.dart).
const int kAutoLockTimeoutMs = 5 * 60 * 1000; // 5 хвилин
const String kLockBgTimeKey = 'lock_background_time';

/// Воротар автоблокування на рівні застосунку. Тримає екран блокування **прямо
/// в дереві** (а не пушить маршрут), тож після таймауту у фоні застосунок
/// одразу відкривається заблокованим, без гонки з навігацією.
///
/// Privacy-шторки тут свідомо немає: у чистому Flutter її неможливо показати при
/// згортанні, не блимаючи при опусканні шторки сповіщень (це одна подія
/// `inactive`, а `paused`/`hidden` уже не малюють кадр).
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  final bool initiallyLocked;

  const AppLockGate({
    super.key,
    required this.child,
    this.initiallyLocked = false,
  });

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late bool _locked;
  bool _wasResumed = true;

  @override
  void initState() {
    super.initState();
    _locked = widget.initiallyLocked;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _pinSet =>
      ref.read(sharedPreferencesProvider).getBool('pin_set_cache') ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prefs = ref.read(sharedPreferencesProvider);

    if (state == AppLifecycleState.resumed) {
      _wasResumed = true;

      // Уже заблоковано / триває довірена системна дія (file picker, share,
      // Google-вхід, біометрія) / PIN вимкнено — не блокуємо.
      if (_locked || AppLock.isTrusted || !_pinSet) return;

      final bgTime = prefs.getInt(kLockBgTimeKey);
      if (bgTime != null &&
          DateTime.now().millisecondsSinceEpoch - bgTime >=
              kAutoLockTimeoutMs) {
        unawaited(prefs.remove(kLockBgTimeKey));
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Фіксуємо час фону лише коли застосунок реально йде у фон і не під час
      // довіреної дії (інакше повернення з file picker/біометрії перезаблокує).
      if (_locked || AppLock.isTrusted) return;
      if (_wasResumed) {
        _wasResumed = false;
        prefs.setInt(kLockBgTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
    }
  }

  void _onUnlocked() {
    if (!mounted) return;
    // Прибираємо час фону, щоб подія resumed після діалогу біометрії не
    // спричинила повторне блокування (інакше — подвійний запит відбитка).
    unawaited(ref.read(sharedPreferencesProvider).remove(kLockBgTimeKey));
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            key: const ValueKey('lb_lock'),
            child: LockScreen(onUnlocked: _onUnlocked),
          ),
      ],
    );
  }
}
