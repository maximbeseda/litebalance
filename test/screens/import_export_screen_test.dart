import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/screens/import_export_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ==========================================
// 1. МОК-НОТИФІКАТОРИ
// ==========================================

class TestCategoryNotifier extends CategoryNotifier {
  final CategoryState mockState;
  TestCategoryNotifier(this.mockState);
  @override
  CategoryState build() => mockState;
}

class TestTransactionNotifier extends TransactionNotifier {
  final TransactionState mockState;
  TestTransactionNotifier(this.mockState);
  @override
  Future<TransactionState> build() async => mockState;
}

void main() {
  // Налаштування для запобігання overflow взагалі (на всякий випадок)
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // ==========================================
  // 2. ДАНІ (ВРАХОВУЮЧИ ТВОЮ Drift-БАЗУ)
  // ==========================================

  // dummyAccount робимо const, щоб прибрати підкреслення лінтера
  const dummyAccount = Category(
    id: 'acc_1',
    type: CategoryType.account,
    name: 'Wallet',
    icon: 0xe041,
    bgColor: 0xFF2196F3,
    iconColor: 0xFFFFFFFF,
    amount: 1000,
    budget: null,
    isArchived: false,
    currency: 'UAH',
    includeInTotal: true,
    sortOrder: 0,
    deletedAt: null,
  );

  final dummyTx = Transaction(
    id: 'tx_1',
    fromId: 'acc_1',
    toId: 'exp_1',
    title: 'Test',
    titleLower: 'test',
    date: DateTime(2026, 4, 27),
    amount: 100,
    currency: 'UAH',
    targetAmount: null,
    targetCurrency: null,
    baseAmount: 100,
    baseCurrency: 'UAH',
    deletedAt: null,
  );

  final defaultCategoryState = CategoryState(
    incomes: const [],
    accounts: const [dummyAccount],
    expenses: const [],
    archivedCategories: const [],
    deletedCategories: const [],
    isLoading: false,
  );

  final defaultTransactionState = TransactionState(
    history: [dummyTx],
    deletedHistory: const [],
    selectedMonth: DateTime(2026, 4, 1),
    isMigrating: false,
  );

  // ==========================================
  // 3. ДОПОМІЖНИЙ ВІДЖЕТ
  // ==========================================

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        categoryProvider.overrideWith(
          () => TestCategoryNotifier(defaultCategoryState),
        ),
        transactionProvider.overrideWith(
          () => TestTransactionNotifier(defaultTransactionState),
        ),
      ],
      child: MaterialApp(
        // Використовуємо AppColorsExtension, щоб імпорт не був Unused
        theme: ThemeData(
          extensions: const [
            AppColorsExtension(
              bgGradientStart: Colors.blue,
              bgGradientEnd: Colors.blueAccent,
              cardBg: Colors.white,
              textMain: Colors.black,
              textSecondary: Colors.grey,
              income: Colors.green,
              expense: Colors.red,
              iconBg: Colors.grey,
              accent: Colors.orange,
            ),
          ],
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const ImportExportScreen(), // Const конструктор екрана
      ),
    );
  }

  // ==========================================
  // 4. ТЕСТИ (БЕЗ КАЛЕНДАРЯ)
  // ==========================================

  group('ImportExportScreen Stable UI Tests', () {
    testWidgets('Відображає головні елементи керування даними', (tester) async {
      // Ставимо великий розмір лише щоб Layout не "кричав" при рендері шіта
      tester.view.physicalSize = const Size(1200, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Перевіряємо, що екран живий
      expect(find.text('data_management'), findsOneWidget);
      expect(find.text('export_csv'), findsOneWidget);
      expect(find.text('import_csv'), findsOneWidget);
    });

    testWidgets('Кнопка Експорт реагує на натискання', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Тиснемо на кнопку експорту
      await tester.tap(find.text('export_button'));
      await tester.pump(); // Рендеримо кадр з індикатором завантаження

      // Перевіряємо наявність лоадера (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('Кнопка Імпорт присутня на екрані', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Просто перевіряємо, що кнопка імпорту є
      expect(find.text('import_button'), findsOneWidget);
    });
  });
}
