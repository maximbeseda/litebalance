import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litebalance/widgets/common/app_picker_sheet.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  // Допоміжна кнопка, що відкриває пікер із пошуком і трьома валютами.
  Widget buildOpener({void Function(String)? onSelected}) {
    return makeTestableWidget(
      child: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => AppPickerSheet.show<String>(
            context: ctx,
            title: 'Currency',
            selected: 'USD',
            enableSearch: true,
            onSelected: onSelected ?? (_) {},
            options: const [
              AppPickerOption(value: 'USD', label: 'US Dollar'),
              AppPickerOption(value: 'EUR', label: 'Euro'),
              AppPickerOption(value: 'KES', label: 'Kenyan Shilling'),
            ],
          ),
          child: const Text('open'),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(buildOpener());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('показує всі варіанти, поки пошук порожній', (tester) async {
    await openSheet(tester);

    expect(find.text('US Dollar'), findsOneWidget);
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('Kenyan Shilling'), findsOneWidget);
  });

  testWidgets('фільтрує за тікером (кодом валюти)', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'kes');
    await tester.pump();

    expect(find.text('Kenyan Shilling'), findsOneWidget);
    expect(find.text('US Dollar'), findsNothing);
    expect(find.text('Euro'), findsNothing);
  });

  testWidgets('фільтрує за назвою валюти', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'euro');
    await tester.pump();

    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('US Dollar'), findsNothing);
    expect(find.text('Kenyan Shilling'), findsNothing);
  });

  testWidgets('пошук без збігів показує порожній стан', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pump();

    expect(find.text('US Dollar'), findsNothing);
    expect(find.text('Euro'), findsNothing);
    expect(find.text('Kenyan Shilling'), findsNothing);
  });

  testWidgets('тап по відфільтрованому варіанту повертає його значення', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(buildOpener(onSelected: (v) => picked = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kenyan');
    await tester.pump();
    await tester.tap(find.text('Kenyan Shilling'));
    await tester.pumpAndSettle();

    expect(picked, 'KES');
  });
}
