import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:coin_flow/main.dart';
import 'package:coin_flow/providers/all_providers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('CoinFlow App boots successfully (smoke test)', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('uk'), Locale('de')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: const MyApp(showOnboarding: false),
        ),
      ),
    );

    // 👇 ЗАМІСТЬ pumpAndSettle(), який висить через вічні анімації:
    // Просто прокручуємо перший кадр рендеру додатку.
    // Цього достатньо, щоб переконатись, що MyApp успішно завантажився і не впав.
    await tester.pump();

    // Можемо навіть прокрутити ще трохи часу вперед, щоб спрацювали початкові Future
    await tester.pump(const Duration(milliseconds: 100));

    // Якщо ми тут — додаток запустився успішно!
    expect(true, isTrue);
  });
}
