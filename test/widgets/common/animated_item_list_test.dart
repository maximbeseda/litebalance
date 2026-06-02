import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/widgets/common/animated_item_list.dart';
import '../../helpers/test_wrapper.dart';

class _Harness extends StatefulWidget {
  final List<String> initial;
  const _Harness(this.initial);
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<String> items = List.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => items = [...items, 'D']),
          child: const Text('add'),
        ),
        ElevatedButton(
          onPressed: () => setState(() => items = items.where((e) => e != 'B').toList()),
          child: const Text('remove'),
        ),
        Expanded(
          child: AnimatedItemList<String>(
            items: items,
            keyOf: (e) => e,
            itemBuilder: (context, e) => SizedBox(height: 40, child: Text(e)),
          ),
        ),
      ],
    );
  }
}

void main() {
  group('AnimatedItemList Tests', () {
    testWidgets('1. Рендерить початкові елементи', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(child: const _Harness(['A', 'B', 'C'])),
      );
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('2. Додавання нового елемента анімовано з\'являється', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(child: const _Harness(['A', 'B', 'C'])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('3. Видалений елемент зникає після анімації', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(child: const _Harness(['A', 'B', 'C'])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('remove'));
      await tester.pumpAndSettle();

      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });
  });
}
