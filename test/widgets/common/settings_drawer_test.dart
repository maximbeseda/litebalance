import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:coin_flow/widgets/common/settings_drawer.dart';
import 'package:coin_flow/providers/all_providers.dart';
import '../../helpers/test_wrapper.dart';

// ==========================================
// МОКИ ДЛЯ RIVERPOD
// ==========================================
class MockSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return SettingsState(
      baseCurrency: 'UAH',
      selectedCurrencies: ['UAH', 'USD'],
      exchangeRates: {},
      historicalCache: {},
    );
  }
}

void main() {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildDrawerApp() async {
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // 👇 ДОДАЄМО МОК: блокуємо завантаження курсів валют
        settingsProvider.overrideWith(() => MockSettingsNotifier()),
      ],
      child: makeTestableWidget(
        child: Scaffold(
          key: scaffoldKey,
          body: const Center(child: Text('Home Screen')),
          drawer: const SettingsDrawer(),
        ),
      ),
    );
  }

  group('SettingsDrawer Tests', () {
    testWidgets('1. Відкриває Drawer та рендерить всі пункти меню', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp());

      scaffoldKey.currentState?.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
      expect(find.byIcon(Icons.currency_exchange), findsOneWidget);
      expect(find.byIcon(Icons.import_export), findsOneWidget);
      expect(find.byIcon(Icons.save_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.autorenew), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('2. Відкриває екран бекапу та перевіряє нові елементи', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildDrawerApp());

      scaffoldKey.currentState?.openDrawer();
      await tester.pumpAndSettle();

      // Клікаємо на пункт бекапу в Drawer
      await tester.tap(find.byIcon(Icons.save_alt_rounded));

      // Чекаємо на push нового екрану (BackupManagementScreen)
      await tester.pumpAndSettle();

      // Перевіряємо НОВІ іконки нашого оновленого екрану,
      // щоб впевнитися, що перехід відбувся успішно
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      // 💡 Перевірку TextField звідси видалено, бо вона тепер живе
      // у файлі backup_management_screen_test.dart
    });
  });
}
