import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/all_providers.dart';
import '../../screens/lock_screen.dart';
import '../../theme/app_colors_extension.dart';
import '../../utils/app_lock.dart';
import 'app_logo.dart';

// Публічні константи автоблокування (використовуються тут і в main.dart).
const int kAutoLockTimeoutMs = 5 * 60 * 1000; // 5 хвилин
const String kLockBgTimeKey = 'lock_background_time';

/// Накладка-«воротар» на рівні застосунку. Тримає шторку/екран блокування
/// **прямо в дереві** (а не пушить маршрут і не вставляє overlay) — тому перший
/// же кадр після повернення з фону вже накритий, без проблиску даних.
///
/// • Коли застосунок іде у фон (`paused`/`hidden`) — вмикаємо шторку з лого; її
///   ж бачить і прев'ю в списку нещодавніх. `inactive` (шторка сповіщень,
///   системні діалоги, біометрія) свідомо ігноруємо, щоб не блимати шторкою.
/// • На `resumed`: якщо минув таймаут і є PIN — показуємо екран блокування
///   тут само (без гонки з push); інакше знімаємо шторку.
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
  bool _shield = false;
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

      // Уже заблоковано (холодний старт) / триває довірена системна дія
      // (file picker, share, Google-вхід) / PIN вимкнено — нічого не блокуємо,
      // лише прибираємо шторку, якщо була.
      if (_locked || AppLock.isTrusted || !_pinSet) {
        if (_shield) setState(() => _shield = false);
        return;
      }

      final bgTime = prefs.getInt(kLockBgTimeKey);
      final elapsed = bgTime == null
          ? 0
          : DateTime.now().millisecondsSinceEpoch - bgTime;

      if (bgTime != null && elapsed >= kAutoLockTimeoutMs) {
        unawaited(prefs.remove(kLockBgTimeKey));
        setState(() {
          _locked = true;
          _shield = false;
        });
      } else if (_shield) {
        setState(() => _shield = false);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // ТІЛЬКИ реальний фон. `inactive` свідомо НЕ обробляємо: він спрацьовує на
      // шторку сповіщень, системні діалоги, діалог біометрії тощо — там шторка
      // не потрібна й лише дратує. `paused` встигає накрити свайп-згортання та
      // знімок «нещодавніх».
      if (_locked || AppLock.isTrusted) return;

      if (_wasResumed) {
        _wasResumed = false;
        prefs.setInt(kLockBgTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
      if (_pinSet && !_shield) {
        setState(() => _shield = true);
      }
    }
  }

  void _onUnlocked() {
    if (!mounted) return;
    // Прибираємо час фону, щоб подія resumed після діалогу біометрії не
    // спричинила повторне блокування (інакше — подвійний запит відбитка).
    unawaited(ref.read(sharedPreferencesProvider).remove(kLockBgTimeKey));
    setState(() {
      _locked = false;
      _shield = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_shield && !_locked)
          const Positioned.fill(
            key: ValueKey('lb_shield'),
            child: _PrivacyShield(),
          ),
        if (_locked)
          Positioned.fill(
            key: const ValueKey('lb_lock'),
            child: LockScreen(onUnlocked: _onUnlocked),
          ),
      ],
    );
  }
}

/// Повноекранна «шторка» з лого, що накриває вміст, поки застосунок не на
/// передньому плані (фон / список нещодавніх / мить при поверненні).
class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>();
    final bg = colors?.cardBg ?? Theme.of(context).scaffoldBackgroundColor;
    return Material(
      color: bg,
      child: const Center(child: AppLogo(size: 200, halo: true)),
    );
  }
}
