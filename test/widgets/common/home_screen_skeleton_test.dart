import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litebalance/widgets/common/home_screen_skeleton.dart';
import 'package:litebalance/theme/app_theme.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  void setupScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
  }

  group('HomeScreenSkeleton Tests', () {
    testWidgets('1. Перевірка структури та анімації', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);

      await tester.pumpWidget(
        makeTestableWidget(
          // ВИПРАВЛЕНО: Прибрали const перед Theme
          child: Theme(
            data: AppTheme.getTheme('light'),
            child: const HomeScreenSkeleton(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      expect(find.byType(HomeScreenSkeleton), findsOneWidget);

      final fadeFinder = find
          .descendant(
            of: find.byType(HomeScreenSkeleton),
            matching: find.byType(FadeTransition),
          )
          .first;

      double getOpacity() =>
          (tester.widget(fadeFinder) as FadeTransition).opacity.value;

      expect(getOpacity(), closeTo(0.3, 0.01));
      await tester.pump(const Duration(milliseconds: 500));
      expect(getOpacity(), greaterThan(0.3));

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Світла тема: Колір пульсації 0.05', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);

      await tester.pumpWidget(
        makeTestableWidget(
          child: Theme(
            data: AppTheme.getTheme('light'),
            child: const HomeScreenSkeleton(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // ВИПРАВЛЕНО: const замість final
      const lightColorAlpha = 0.05;
      final pulses = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final deco = widget.decoration as BoxDecoration;
          return deco.color != null &&
              (deco.color!.a - lightColorAlpha).abs() < 0.01;
        }
        return false;
      });

      expect(pulses, findsAtLeastNWidgets(5));
      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Темна тема: Колір пульсації 0.12', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);

      await tester.pumpWidget(
        makeTestableWidget(
          child: Theme(
            data: AppTheme.getTheme('dark'),
            child: const HomeScreenSkeleton(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);

      // ВИПРАВЛЕНО: const замість final
      const darkColorAlpha = 0.12;
      final pulses = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final deco = widget.decoration as BoxDecoration;
          return deco.color != null &&
              (deco.color!.a - darkColorAlpha).abs() < 0.01;
        }
        return false;
      });

      expect(pulses, findsAtLeastNWidgets(5));
      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
