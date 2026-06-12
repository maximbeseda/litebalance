import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coin_flow/screens/backup_management_screen.dart';
import 'package:coin_flow/theme/app_colors_extension.dart';
import 'package:coin_flow/providers/all_providers.dart';
import 'package:coin_flow/services/drive_backup_service.dart';

class MockDriveBackupService extends Mock implements DriveBackupService {}

class MockAppDatabase extends Mock implements AppDatabase {}

// 👇 ОНОВЛЕНИЙ ФЕЙКОВИЙ ПРОВАЙДЕР
class FakeSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      baseCurrency: 'UAH',
      selectedCurrencies: ['UAH'],
      exchangeRates: {},
      historicalCache: {},
      lastCloudBackup: null,
      lastFileBackup: null,
    );
  }

  // ✅ Додаємо заглушки для методів, щоб вони не лізли в SharedPreferences
  @override
  Future<void> updateCloudBackupTime() async {
    state = state.copyWith(lastCloudBackup: DateTime.now());
  }

  @override
  Future<void> updateFileBackupTime() async {
    state = state.copyWith(lastFileBackup: DateTime.now());
  }
}

class FakeAppColors extends AppColorsExtension {
  FakeAppColors()
    : super(
        cardBg: Colors.white,
        income: Colors.green,
        expense: Colors.red,
        textMain: Colors.black,
        textSecondary: Colors.grey,
        bgGradientStart: Colors.white,
        bgGradientEnd: Colors.white,
        iconBg: Colors.grey,
        accent: Colors.blue,
      );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? accent,
    Color? bgGradientEnd,
    Color? bgGradientStart,
    Color? cardBg,
    Color? expense,
    Color? iconBg,
    Color? income,
    Color? textMain,
    Color? textSecondary,
    Color? warning,
    Color? divider,
    Color? shadow,
  }) => this;

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) => this;
}

void main() {
  late MockDriveBackupService mockDriveBackup;
  late MockAppDatabase mockDb;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    mockDriveBackup = MockDriveBackupService();
    mockDb = MockAppDatabase();

    // Вчимо наш мок-сервіс успішно виконувати бекап
    when(
      () => mockDriveBackup.backupDatabase(mockDb),
    ).thenAnswer((_) async => true);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        driveBackupServiceProvider.overrideWithValue(mockDriveBackup),
        appDatabaseProvider.overrideWithValue(mockDb),
        settingsProvider.overrideWith(() => FakeSettingsNotifier()),
      ],
      child: MaterialApp(
        theme: ThemeData().copyWith(extensions: [FakeAppColors()]),
        home: const BackupManagementScreen(),
      ),
    );
  }

  group('BackupManagementScreen Tests', () {
    testWidgets('Екран рендериться коректно і показує всі елементи меню', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('backup_title'), findsOneWidget);
      expect(find.text('google_drive_backup'.toUpperCase()), findsOneWidget);
      // Ручний бекап на Drive прибрано — лишилось лише відновлення з хмари.
      expect(find.text('sync_with_cloud'), findsNothing);
      expect(find.text('import_from_cloud'), findsOneWidget);

      expect(find.text('file_backup'.toUpperCase()), findsOneWidget);
      expect(find.text('export_to_file'), findsOneWidget);
      expect(find.text('import_from_file'), findsOneWidget);
    });

    testWidgets('Відновлення з хмари показує список версій і діалог підтвердження', (
      WidgetTester tester,
    ) async {
      when(() => mockDriveBackup.listCloudBackups()).thenAnswer(
        (_) async => [
          CloudBackupInfo(
            id: '1',
            date: DateTime(2026, 6, 1, 12, 0),
            sizeBytes: 50000,
            isCurrent: true,
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('import_from_cloud'));
      await tester.pumpAndSettle();

      // З'явився список версій з позначкою «поточна копія».
      expect(find.textContaining('current_copy'), findsOneWidget);

      // Тап по версії → діалог підтвердження відновлення.
      await tester.tap(find.text('01.06.2026 12:00'));
      await tester.pumpAndSettle();

      expect(find.text('cloud_restore_confirm'), findsOneWidget);
      expect(find.text('confirm'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
    });

    testWidgets('Натискання на експорт у файл викликає запит пароля', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final exportButton = find.text('export_to_file');

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text('backup_protection_title'), findsOneWidget);
      expect(find.text('export_password_hint'), findsOneWidget);
    });
  });
}
