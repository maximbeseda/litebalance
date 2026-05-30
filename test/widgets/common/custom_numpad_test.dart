import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coin_flow/widgets/common/custom_numpad.dart';
import 'package:coin_flow/providers/all_providers.dart';
import '../../helpers/test_wrapper.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSharedPreferences mockPrefs;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'hasVibrator') return false;
          return null;
        });
  });

  setUp(() {
    mockPrefs = MockSharedPreferences();
    when(() => mockPrefs.getBool(any())).thenReturn(null);
  });

  group('CustomNumpad Tests', () {
    testWidgets('Повинен рендерити всі цифри та оператори', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: CustomNumpad(onKeyPressed: (_) {}),
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        ),
      );

      for (int i = 0; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
      expect(find.text('00'), findsOneWidget);

      expect(find.text('C'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('÷'), findsOneWidget);
      expect(find.text('×'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('='), findsOneWidget);

      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('Повинен передавати правильне значення при натисканні', (
      WidgetTester tester,
    ) async {
      String? pressedKey;

      await tester.pumpWidget(
        makeTestableWidget(
          child: CustomNumpad(
            onKeyPressed: (key) {
              pressedKey = key;
            },
          ),
          overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        ),
      );

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(pressedKey, '5');

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(pressedKey, '+');

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(pressedKey, '⌫');
    });
  });
}
