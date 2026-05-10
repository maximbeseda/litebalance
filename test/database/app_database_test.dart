import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:coin_flow/database/app_database.dart';
import 'package:sqlite3/common.dart'; // Тепер це працюватиме

class _DummyUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
  @override
  int get schemaVersion => 1;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Явно вказуємо типи, щоб уникнути avoid_dynamic_calls
  void databaseSetup(CommonDatabase database) {
    database.createFunction(
      functionName: 'dart_lower',
      function: (List<Object?> args) {
        if (args.isNotEmpty) {
          final Object? firstArg = args[0];
          if (firstArg is String) {
            return firstArg.toLowerCase();
          }
          return firstArg;
        }
        return null;
      },
    );
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return Directory.systemTemp.path;
          },
        );
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: databaseSetup));
  });

  tearDown(() async {
    await db.closeConnection();
  });

  group('AppDatabase - Складні тести', () {
    test('Міграція та перевірка QueryRow', () async {
      final NativeDatabase executor = NativeDatabase.memory(
        setup: databaseSetup,
      );
      await executor.ensureOpen(_DummyUser());

      await executor.runCustom(
        'CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY, type INTEGER NOT NULL, name TEXT NOT NULL, icon INTEGER NOT NULL, bg_color INTEGER NOT NULL, icon_color INTEGER NOT NULL, amount INTEGER NOT NULL DEFAULT 0, budget INTEGER, is_archived BOOLEAN NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT \'UAH\', include_in_total BOOLEAN NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0);',
      );
      await executor.runCustom(
        'CREATE TABLE transactions (id TEXT NOT NULL PRIMARY KEY, from_id TEXT NOT NULL, to_id TEXT NOT NULL, title TEXT NOT NULL, date INTEGER NOT NULL, amount INTEGER NOT NULL, currency TEXT NOT NULL, target_amount INTEGER, target_currency TEXT, base_amount INTEGER NOT NULL DEFAULT 0, base_currency TEXT NOT NULL);',
      );
      await executor.runCustom(
        'CREATE TABLE subscriptions (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, amount INTEGER NOT NULL, category_id TEXT NOT NULL, account_id TEXT NOT NULL, next_payment_date INTEGER NOT NULL, periodicity TEXT NOT NULL DEFAULT \'monthly\', custom_icon_code_point INTEGER, is_auto_pay BOOLEAN NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT \'UAH\');',
      );

      final AppDatabase upgradeDb = AppDatabase(executor);
      final Migrator m = Migrator(upgradeDb);

      await upgradeDb.customStatement(
        'INSERT INTO transactions (id, from_id, to_id, title, date, amount, currency, base_currency) VALUES (\'t1\', \'a\', \'b\', \'Coffee\', 1700000000, 50, \'UAH\', \'UAH\')',
      );

      await upgradeDb.migration.onUpgrade(m, 1, 3);

      // 👇 ФІКС: customSelect тепер повертає Selectable<QueryRow>
      final Selectable<QueryRow> selectable = upgradeDb.customSelect(
        'SELECT title_lower FROM transactions WHERE id = \'t1\'',
      );
      final QueryRow row = await selectable.getSingle();

      expect(row.read<String>('title_lower'), 'coffee');
      await upgradeDb.close();
    });

    test('Drift Managers - використання Value', () async {
      // 👇 ФІКС: Менеджери очікують Value<T>, а не просто T
      await db.managers.categories.create(
        (o) => o(
          id: 'm1',
          name: 'Manager',
          type: CategoryType.income,
          icon: 0,
          bgColor: 0,
          iconColor: 0,
          amount: const Value(0),
          isArchived: const Value(false),
        ),
      );

      final int count = await db.managers.categories.count();
      expect(count, 1);
    });
  });
}
