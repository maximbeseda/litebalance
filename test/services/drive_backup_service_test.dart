import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:coin_flow/services/drive_backup_service.dart';
import 'package:coin_flow/services/google_auth_service.dart';
import 'package:coin_flow/database/app_database.dart';

class AppDatabaseSpy extends Fake implements AppDatabase {
  static int checkpointCalls = 0;
  static int closeCalls = 0;

  static void reset() {
    checkpointCalls = 0;
    closeCalls = 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #forceCheckpoint) {
      checkpointCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #closeConnection) {
      closeCalls++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> forceCheckpoint() async => checkpointCalls++;

  @override
  Future<void> closeConnection() async => closeCalls++;
}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockHttpClient extends Mock implements http.Client {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
  });

  late MockGoogleAuthService mockAuth;
  late AppDatabaseSpy spyDb;
  late DriveBackupService service;
  late Directory tempDir;

  setUp(() async {
    AppDatabaseSpy.reset();
    mockAuth = MockGoogleAuthService();
    spyDb = AppDatabaseSpy();
    service = DriveBackupService(mockAuth);

    tempDir = await Directory.systemTemp.createTemp('coinflow_final_victory');

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async => tempDir.path);
  });

  tearDown(() async {
    // 👇 ХАК ДЛЯ WINDOWS: Ігноруємо помилки блокування файлів
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      // Файл заблокований ОС, він видалиться сам при очищенні Temp ОС Windows
    }
  });

  group('DriveBackupService - Victory Tests', () {
    test('backupDatabase викликає forceCheckpoint', () async {
      final mockClient = MockHttpClient();
      when(
        () => mockAuth.getAuthenticatedClient(),
      ).thenAnswer((_) async => mockClient);

      when(() => mockClient.send(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as http.BaseRequest;
        // 👇 ЗАКРИВАЄМО ПОТІК, щоб Windows не блокував файл
        if (req is http.StreamedRequest) {
          await req.finalize().drain();
        }

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'files': []}))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final dbFile = File(p.join(tempDir.path, 'coinflow_db.sqlite'));
      await dbFile.writeAsString('fake data');

      await service.backupDatabase(spyDb);

      expect(AppDatabaseSpy.checkpointCalls, 1);
    });

    test('restoreDatabase закриває з’єднання перед заміною файлів', () async {
      final mockClient = MockHttpClient();
      when(
        () => mockAuth.getAuthenticatedClient(),
      ).thenAnswer((_) async => mockClient);

      int requestCount = 0;
      when(() => mockClient.send(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as http.BaseRequest;
        if (req is http.StreamedRequest) await req.finalize().drain();

        requestCount++;
        if (requestCount == 1) {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'files': [
                    {'id': '1', 'name': 'db'},
                  ],
                }),
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('new content')),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );
      });

      await service.restoreDatabase(spyDb);

      expect(AppDatabaseSpy.closeCalls, 1);
    });

    test('performSmartSync викликає checkpoint при локальних змінах', () async {
      final mockClient = MockHttpClient();
      when(
        () => mockAuth.getAuthenticatedClient(),
      ).thenAnswer((_) async => mockClient);

      when(() => mockClient.send(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as http.BaseRequest;
        if (req is http.StreamedRequest) await req.finalize().drain();

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'files': []}))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final dbFile = File(p.join(tempDir.path, 'coinflow_db.sqlite'));
      await dbFile.writeAsString('local change');

      await service.performSmartSync(spyDb, true);

      expect(AppDatabaseSpy.checkpointCalls, greaterThanOrEqualTo(1));
    });
  });
}
