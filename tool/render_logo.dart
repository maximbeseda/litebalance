import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin_flow/widgets/common/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Генератор брендових PNG-ассетів LiteBalance із віджета [AppLogo].
/// Запуск: `flutter test tool/render_logo.dart`.
/// Результат — у `assets/branding/` (далі споживається flutter_launcher_icons
/// та flutter_native_splash).
const _dir = 'assets/branding';

Future<void> _capture(
  WidgetTester tester,
  Widget child,
  double side,
  String outPath, {
  double? height,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: side, height: height ?? side, child: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(outPath)..parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final f = File('assets/fonts/Quicksand.ttf');
    final bytes = ByteData.view(f.readAsBytesSync().buffer);
    await (FontLoader(AppLogo.fontFamily)..addFont(Future.value(bytes))).load();
  });

  testWidgets('generate branding assets', (tester) async {
    // Іконка запуску: монограм на весь квадрат (OS сама округлює кути).
    await _capture(
      tester,
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppLogo.tileTop, AppLogo.tileBottom],
          ),
        ),
        alignment: Alignment.center,
        child: const AppMonogram(size: 512),
      ),
      512,
      '$_dir/launcher_icon.png',
    );

    // Передній шар adaptive-іконки: монограм у безпечній зоні (тло — у конфізі).
    await _capture(
      tester,
      const Center(child: AppMonogram(size: 338)),
      512,
      '$_dir/launcher_foreground.png',
    );

    // Логотип для нативного сплеша (iOS / Android < 12): круг із монограмом,
    // з полем навколо, щоб коло не торкалося країв і не виглядало обрізаним.
    await _capture(
      tester,
      const Center(child: AppLogo(size: 384)),
      512,
      '$_dir/splash_logo.png',
    );

    // Прев'ю онбординг-лого (круг + сяйво) на світлому тлі — не комітиться.
    await _capture(
      tester,
      Container(
        color: const Color(0xFFE9EEF5),
        alignment: Alignment.center,
        child: const AppLogo(size: 320, halo: true),
      ),
      420,
      'build/logo_preview/onboarding_logo.png',
    );

    // Сплеш Android 12+: система маскує іконку в коло, тож монограм на темному
    // КОЛІ з прозорими полями (вміст у центральній безпечній зоні 1152→коло).
    await _capture(
      tester,
      Center(
        child: Container(
          width: 340,
          height: 340,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppLogo.tileTop, AppLogo.tileBottom],
            ),
          ),
          alignment: Alignment.center,
          child: const AppMonogram(size: 245),
        ),
      ),
      576,
      '$_dir/splash_android12.png',
    );

    expect(File('$_dir/launcher_icon.png').existsSync(), isTrue);
  });

  testWidgets('generate README hero banner', (tester) async {
    await _capture(
      tester,
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101A30), Color(0xFF05070E)],
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(size: 240, halo: true),
            SizedBox(height: 16),
            Text(
              'LiteBalance',
              style: TextStyle(
                fontFamily: AppLogo.fontFamily,
                fontVariations: [FontVariation('wght', 700)],
                fontSize: 64,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Clear, calm money tracking',
              style: TextStyle(
                fontFamily: AppLogo.fontFamily,
                fontVariations: [FontVariation('wght', 700)],
                fontSize: 26,
                color: Color(0xFF8AA9E6),
              ),
            ),
          ],
        ),
      ),
      1200,
      'docs/hero.png',
      height: 630,
    );
    expect(File('docs/hero.png').existsSync(), isTrue);
  });
}
