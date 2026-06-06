import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/widgets/common/category_halo_icon.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('CategoryHaloIcon Tests', () {
    testWidgets('1. Малює іконку категорії потрібним кольором', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const CategoryHaloIcon(
            icon: Icons.fastfood,
            bgColor: Colors.deepPurple,
            iconColor: Colors.white,
            size: 52,
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.icon, equals(Icons.fastfood));
      expect(iconWidget.color, equals(Colors.white));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('2. Має заданий розмір', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const CategoryHaloIcon(
            icon: Icons.home,
            bgColor: Colors.teal,
            iconColor: Colors.white,
            size: 60,
          ),
        ),
      );

      final sized = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(CategoryHaloIcon),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sized.width, equals(60));
      expect(sized.height, equals(60));
    });
  });
}
