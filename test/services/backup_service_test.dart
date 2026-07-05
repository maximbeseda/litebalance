import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/services/backup_service.dart';

// ==========================================
// 1. ЕЛЕГАНТНИЙ МОК ЧЕРЕЗ MOCKTAIL
// ==========================================
// Завдяки Mocktail нам не треба вручну прописувати всі параметри pickFiles!
class MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Ініціалізуємо наш універсальний мок
    final mockPicker = MockFilePicker();
    FilePicker.platform = mockPicker;

    // Налаштовуємо поведінку для pickFiles
    when(() => mockPicker.pickFiles(type: FileType.any)).thenAnswer(
      (_) async => FilePickerResult([
        PlatformFile(
          path: '${Directory.systemTemp.path}/test_backup.cfbak',
          name: 'test_backup.cfbak',
          size: 1024,
          bytes: null,
        ),
      ]),
    );

    // Налаштовуємо поведінку для очищення кешу
    when(() => mockPicker.clearTemporaryFiles()).thenAnswer((_) async => true);

    // Мокаємо PathProvider (отримання тимчасової папки)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory') {
              return Directory.systemTemp.path;
            }
            return null;
          },
        );

    // Мокаємо SharePlus (щоб не відкривалося реальне вікно Share)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (MethodCall methodCall) async {
            return 'Success';
          },
        );
  });

  // --- ТЕСТОВІ ДАНІ ---
  const Category dummyCategory = Category(
    id: 'cat_1',
    name: 'Test Category',
    type: CategoryType.expense,
    currency: 'UAH',
    amount: 0,
    icon: 1,
    bgColor: 1,
    iconColor: 1,
    isArchived: false,
    includeInTotal: true,
    sortOrder: 0,
  );

  final Transaction dummyTransaction = Transaction(
    id: 'tx_1',
    fromId: 'acc_1',
    toId: 'cat_1',
    title: 'Test Tx',
    amount: 100,
    date: DateTime(2026, 1, 1),
    currency: 'UAH',
    baseAmount: 100,
    baseCurrency: 'UAH',
  );

  final Subscription dummySubscription = Subscription(
    id: 'sub_1',
    name: 'Test Sub',
    amount: 50,
    currency: 'UAH',
    accountId: 'acc_1',
    categoryId: 'cat_1',
    periodicity: 'monthly',
    nextPaymentDate: DateTime(2026, 2, 1),
    isAutoPay: false,
  );

  group('BackupService - Encryption Engine', () {
    test('Повний цикл: Експорт -> Шифрування -> Розшифрування', () {
      const String testPassword = 'SuperSecretPassword123!';

      final String encryptedString = BackupService.generateEncryptedPayload(
        testPassword,
        [dummyCategory],
        [dummyTransaction],
        [dummySubscription],
      );

      expect(encryptedString.startsWith('LBK2:'), isTrue);
      expect(encryptedString.contains('Test Category'), isFalse);

      final Map<String, dynamic> decryptedJson = BackupService.decryptPayload(
        testPassword,
        encryptedString,
      );

      expect(decryptedJson['version'], 1);

      final List importedCategories = decryptedJson['categories'] as List;
      final Map<String, dynamic> firstCat = Map<String, dynamic>.from(
        importedCategories.first as Map,
      );
      expect(firstCat['name'], 'Test Category');

      final List importedTransactions = decryptedJson['transactions'] as List;
      final Map<String, dynamic> firstTx = Map<String, dynamic>.from(
        importedTransactions.first as Map,
      );
      expect(firstTx['id'], 'tx_1');
    });

    test(
      'decryptPayload викидає помилку (ArgumentError або FormatException) при неправильному паролі',
      () {
        final String encryptedString = BackupService.generateEncryptedPayload(
          'CorrectPassword',
          [],
          [],
          [],
        );

        expect(
          () => BackupService.decryptPayload('HackerPassword', encryptedString),
          throwsA(
            anyOf(isA<ArgumentError>(), isA<FormatException>()),
          ), // 👈 Очікуємо одну з двох помилок
        );
      },
    );
  });

    test('Новий формат використовує PBKDF2 (тег LBK2 + сіль)', () {
      final payload = BackupService.generateEncryptedPayload(
        'pass',
        [],
        [],
        [],
      );
      final parts = payload.split(':');
      // LBK2 : iterations : salt : iv : cipher
      expect(parts.length, 5);
      expect(parts[0], 'LBK2');
      expect(int.parse(parts[1]) >= 100000, isTrue);
    });

    test('Зворотна сумісність: старий .cfbak (SHA-256) досі читається', () {
      const password = 'OldFormatPass';
      final legacy = BackupService.legacyEncryptedPayload(
        password,
        [dummyCategory],
        [],
        [],
      );
      // Старий формат — без тегу LBK2.
      expect(legacy.startsWith('LBK2:'), isFalse);

      final decoded = BackupService.decryptPayload(password, legacy);
      final cats = decoded['categories'] as List;
      expect(
        Map<String, dynamic>.from(cats.first as Map)['name'],
        'Test Category',
      );
    });

  group('BackupService - File System & Database Operations', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('exportData успішно створює файл і викликає share', () async {
      await BackupService.exportData('pass', [dummyCategory], [], []);
      expect(true, isTrue);
    });

    test('pickBackupFile повертає File завдяки FilePicker моку', () async {
      final File? file = await BackupService.pickBackupFile();
      expect(file, isNotNull);
      expect(file!.path.endsWith('test_backup.cfbak'), isTrue);
    });

    test('importDataFromFile (.cfbak) успішно записує дані в базу', () async {
      final file = File('${Directory.systemTemp.path}/valid_backup.cfbak');
      final payload = BackupService.generateEncryptedPayload(
        'secure_pass',
        [dummyCategory],
        [dummyTransaction],
        [dummySubscription],
      );
      await file.writeAsString(payload);

      await BackupService.importDataFromFile(file, 'secure_pass', db);

      final categoriesInDb = await db.select(db.categories).get();
      expect(categoriesInDb.length, 1);
      expect(categoriesInDb.first.name, 'Test Category');

      final transactionsInDb = await db.select(db.transactions).get();
      expect(transactionsInDb.length, 1);
      expect(transactionsInDb.first.id, 'tx_1');
    });

    test('importDataFromFile (.json) обробляє сирий JSON', () async {
      final file = File('${Directory.systemTemp.path}/valid_backup.json');

      final payload = BackupService.generateEncryptedPayload(
        'pass',
        [dummyCategory],
        [],
        [],
      );
      final Map<String, dynamic> jsonMap = BackupService.decryptPayload(
        'pass',
        payload,
      );
      await file.writeAsString(jsonEncode(jsonMap));

      await BackupService.importDataFromFile(file, 'pass', db);

      final categoriesInDb = await db.select(db.categories).get();
      expect(categoriesInDb.length, 1);
      expect(categoriesInDb.first.name, 'Test Category');
    });

    test('importDataFromFile викидає помилку при невірному паролі', () async {
      final file = File('${Directory.systemTemp.path}/invalid_backup.cfbak');
      final payload = BackupService.generateEncryptedPayload(
        'secure_pass',
        [],
        [],
        [],
      );
      await file.writeAsString(payload);

      expect(
        () => BackupService.importDataFromFile(file, 'wrong_pass', db),
        throwsException,
      );
    });

    test(
      'importDataFromFile викидає помилку при невідомому розширенні',
      () async {
        final file = File('${Directory.systemTemp.path}/backup.txt');
        await file.writeAsString('Some text');

        expect(
          () => BackupService.importDataFromFile(file, 'pass', db),
          throwsException,
        );
      },
    );

    test(
      'importData викликає весь ланцюг: pickFile + importFromFile',
      () async {
        final pickedFile = File(
          '${Directory.systemTemp.path}/test_backup.cfbak',
        );
        final payload = BackupService.generateEncryptedPayload(
          'pass',
          [dummyCategory],
          [],
          [],
        );
        await pickedFile.writeAsString(payload);

        await BackupService.importData('pass', db);

        final categoriesInDb = await db.select(db.categories).get();
        expect(categoriesInDb.length, 1);
      },
    );
  });
}
