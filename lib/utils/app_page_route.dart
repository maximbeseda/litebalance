import 'package:flutter/material.dart';

/// Єдиний перехід між екранами: плавний в'їзд справа + поява.
/// Використовуй замість MaterialPageRoute для звичайної навігації вперед,
/// щоб усі переходи в застосунку були однаковими.
Route<T> appPageRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      // Повноцінний в'їзд справа (як у iOS), щоб напрям був явним.
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
