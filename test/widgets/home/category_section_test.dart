import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:coin_flow/widgets/home/category_section.dart';
import 'package:coin_flow/providers/all_providers.dart';
import '../../helpers/test_wrapper.dart';

// ==========================================
// МОКИ ТА ФЕЙКИ ДЛЯ RIVERPOD 3.0
// ==========================================
class MockCategory extends Mock implements Category {}

class FakeCategory extends Fake implements Category {}

class MockCategoryLogic extends Mock {
  Future<void> moveToTrash(Category category);
  Future<void> reorderCategories(Category source, Category target);
}

class TestCategoryNotifier extends CategoryNotifier {
  final MockCategoryLogic logic;

  TestCategoryNotifier(this.logic);

  @override
  CategoryState build() => CategoryState(
    incomes: const [],
    accounts: const [],
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  @override
  Future<void> moveToTrash(Category category) => logic.moveToTrash(category);

  @override
  Future<void> reorderCategories(Category source, Category target) =>
      logic.reorderCategories(source, target);
}

class TestHomeScreenController extends HomeScreenController {
  final bool initialEditMode;

  TestHomeScreenController({this.initialEditMode = false});

  @override
  HomeScreenState build() => HomeScreenState(isEditMode: initialEditMode);

  @override
  void toggleEditMode() {
    state = state.copyWith(isEditMode: !state.isEditMode);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategory());
  });

  void setupScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
  }

  group('CategorySection Full Coverage Tests (Riverpod 3.0) -', () {
    late MockCategory testCategory1;
    late MockCategory testCategory2;
    late MockCategory testCategoryAccount;
    late MockCategoryLogic mockLogic;

    setUp(() {
      testCategory1 = MockCategory();
      testCategory2 = MockCategory();
      testCategoryAccount = MockCategory();
      mockLogic = MockCategoryLogic();

      when(() => testCategory1.id).thenReturn('test_cat_1');
      when(() => testCategory1.type).thenReturn(CategoryType.expense);
      when(() => testCategory1.name).thenReturn('Їжа');
      when(() => testCategory1.bgColor).thenReturn(0xFF4361EE);
      when(() => testCategory1.icon).thenReturn(0xe25a);
      when(() => testCategory1.iconColor).thenReturn(0xFFFFFFFF);
      when(() => testCategory1.amount).thenReturn(0);
      when(() => testCategory1.currency).thenReturn('₴');

      when(() => testCategory2.id).thenReturn('test_cat_2');
      when(() => testCategory2.type).thenReturn(CategoryType.expense);
      when(() => testCategory2.name).thenReturn('Транспорт');
      when(() => testCategory2.bgColor).thenReturn(0xFFFF5722);
      when(() => testCategory2.icon).thenReturn(0xe1d5);
      when(() => testCategory2.iconColor).thenReturn(0xFFFFFFFF);
      when(() => testCategory2.amount).thenReturn(0);
      when(() => testCategory2.currency).thenReturn('₴');

      when(() => testCategoryAccount.id).thenReturn('acc_1');
      when(() => testCategoryAccount.type).thenReturn(CategoryType.account);
      when(() => testCategoryAccount.name).thenReturn('Готівка');
      when(() => testCategoryAccount.bgColor).thenReturn(0xFF112233);
      when(() => testCategoryAccount.icon).thenReturn(0xe25a);
      when(() => testCategoryAccount.iconColor).thenReturn(0xFFFFFFFF);
      when(() => testCategoryAccount.amount).thenReturn(100);
      when(() => testCategoryAccount.currency).thenReturn('₴');

      when(() => mockLogic.moveToTrash(any())).thenAnswer((_) async {});
      when(
        () => mockLogic.reorderCategories(any(), any()),
      ).thenAnswer((_) async {});
    });

    Widget createCategorySection(
      WidgetTester tester, {
      required List<Category> categories,
      bool isGrid = false,
      bool isTarget = false,
      Function(Category, Category)? onTransfer,
      Future<dynamic> Function(Category)? onEditTap,
      VoidCallback? onAddTap,
      TestHomeScreenController? customHomeController,
    }) {
      return ProviderScope(
        overrides: [
          if (customHomeController != null)
            homeScreenControllerProvider.overrideWith(
              () => customHomeController,
            ),
          categoryProvider.overrideWith(() => TestCategoryNotifier(mockLogic)),
        ],
        child: makeTestableWidget(
          child: CategorySection(
            categories: categories,
            type: CategoryType.expense,
            isGrid: isGrid,
            isTarget: isTarget,
            onTransfer: onTransfer ?? (_, _) {},
            onHistoryTap: (_) {},
            onEditTap: onEditTap ?? (_) async => null,
            onAddTap: onAddTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('1. Рендерить секцію, кнопку Add та список категорій', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createCategorySection(tester, categories: [testCategory1]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(LongPressDraggable<Category>), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('2. Натискання на кнопку Add викликає onAddTap', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);
      bool isAddTapped = false;

      await tester.pumpWidget(
        createCategorySection(
          tester,
          categories: const [],
          onAddTap: () => isAddTapped = true,
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(isAddTapped, isTrue);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('3. Натискання на категорію викликає onHistoryTap', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);
      Category? tappedCategory;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryProvider.overrideWith(
              () => TestCategoryNotifier(mockLogic),
            ),
          ],
          child: makeTestableWidget(
            child: CategorySection(
              categories: [testCategory1],
              type: CategoryType.expense,
              onTransfer: (_, _) {},
              onHistoryTap: (cat) => tappedCategory = cat,
              onEditTap: (_) async => null,
              onAddTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(LongPressDraggable<Category>));
      await tester.pumpAndSettle();

      expect(tappedCategory?.id, equals('test_cat_1'));

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('4. Режим редагування: є іконка редагування і Draggable', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);
      final homeController = TestHomeScreenController(initialEditMode: true);

      await tester.pumpWidget(
        createCategorySection(
          tester,
          categories: [testCategory1],
          customHomeController: homeController,
        ),
      );

      await tester.pump();

      expect(find.byType(Draggable<Category>), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
      '5. Натискання на іконку "delete" видаляє категорію (Riverpod 3.0 Test)',
      (WidgetTester tester) async {
        setupScreenSize(tester);
        final homeController = TestHomeScreenController(initialEditMode: true);

        await tester.pumpWidget(
          createCategorySection(
            tester,
            categories: [testCategory1],
            customHomeController: homeController,
            onEditTap: (_) async => 'delete',
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(() => mockLogic.moveToTrash(testCategory1)).called(1);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '6. Drag & Drop з іншої секції викликає onTransfer (переказ коштів)',
      (WidgetTester tester) async {
        setupScreenSize(tester);
        Category? sourceCat;
        Category? targetCat;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              categoryProvider.overrideWith(
                () => TestCategoryNotifier(mockLogic),
              ),
            ],
            child: makeTestableWidget(
              child: Column(
                children: [
                  Draggable<Category>(
                    data: testCategoryAccount,
                    feedback: const Text('Dragging'),
                    // 👇 ФІКС: Надали колір, щоб Flutter міг "схопити" цей віджет!
                    child: Container(
                      color: Colors.red,
                      width: 50,
                      height: 50,
                      key: const ValueKey('external_drag'),
                    ),
                  ),
                  CategorySection(
                    categories: [testCategory1],
                    type: CategoryType.expense,
                    isTarget: true,
                    onTransfer: (src, tgt) {
                      sourceCat = src;
                      targetCat = tgt;
                    },
                    onHistoryTap: (_) {},
                    onEditTap: (_) async => null,
                    onAddTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final externalDrag = find.byKey(const ValueKey('external_drag'));
        final targetExpense = find.byKey(const ValueKey('test_cat_1'));

        // 👇 ФІКС: Використовуємо надійний tester.drag
        final offset =
            tester.getCenter(targetExpense) - tester.getCenter(externalDrag);
        await tester.drag(externalDrag, offset);
        await tester.pumpAndSettle();

        expect(sourceCat?.id, 'acc_1');
        expect(targetCat?.id, 'test_cat_1');

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets(
      '7. Drag & Drop в режимі редагування викликає reorderCategories (сортування)',
      (WidgetTester tester) async {
        setupScreenSize(tester);
        final homeController = TestHomeScreenController(initialEditMode: true);

        await tester.pumpWidget(
          createCategorySection(
            tester,
            categories: [testCategory1, testCategory2],
            customHomeController: homeController,
          ),
        );

        await tester.pump();

        final firstCategory = find.byKey(const ValueKey('test_cat_1'));
        final secondCategory = find.byKey(const ValueKey('test_cat_2'));

        // 👇 ФІКС: Також замінили на надійний tester.drag
        final offset =
            tester.getCenter(secondCategory) - tester.getCenter(firstCategory);
        await tester.drag(firstCategory, offset);

        // Просто промальовуємо кілька кадрів для завершення дропу (але без pumpAndSettle, щоб не зависло на анімації тряски)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockLogic.reorderCategories(testCategory1, testCategory2),
        ).called(1);

        addTearDown(tester.view.resetPhysicalSize);
      },
    );

    testWidgets('8. Перевірка рендерингу у форматі Grid (isGrid = true)', (
      WidgetTester tester,
    ) async {
      setupScreenSize(tester);
      await tester.pumpWidget(
        createCategorySection(
          tester,
          categories: [testCategory1, testCategory2],
          isGrid: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
