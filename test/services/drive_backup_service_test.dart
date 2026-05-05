import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:coin_flow/services/drive_backup_service.dart';
import 'package:coin_flow/services/google_auth_service.dart';
import 'package:coin_flow/database/app_database.dart';

// 1. Створюємо "фальшиві" класи для наших залежностей
class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  // Це потрібно для роботи з системними каналами у тестах (наприклад, path_provider)
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleAuthService mockAuthService;
  late MockAppDatabase mockDb;
  late DriveBackupService backupService;

  setUp(() {
    // 2. Ініціалізуємо чисті моби перед кожним тестом
    mockAuthService = MockGoogleAuthService();
    mockDb = MockAppDatabase();
    backupService = DriveBackupService(mockAuthService);

    // 3. "Заглушка" для path_provider
    // Коли код проситиме шлях до папки документів, ми повертатимемо поточну директорію
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '.'; // Поточна папка для тестів
          }
          return null;
        });
  });

  group('DriveBackupService Tests', () {
    test(
      'backupDatabase повертає false, якщо клієнт не авторизований',
      () async {
        // Умова: користувач не увійшов в Google (повертаємо null)
        when(
          () => mockAuthService.getAuthenticatedClient(),
        ).thenAnswer((_) async => null);

        final result = await backupService.backupDatabase(mockDb);

        // Перевірка: сервіс має одразу повернути false
        expect(result, isFalse);

        // Перевірка: ми не повинні були намагатися робити checkpoint бази
        verifyNever(() => mockDb.forceCheckpoint());
      },
    );

    test(
      'restoreDatabase повертає false, якщо клієнт не авторизований',
      () async {
        when(
          () => mockAuthService.getAuthenticatedClient(),
        ).thenAnswer((_) async => null);

        final result = await backupService.restoreDatabase(mockDb);

        expect(result, isFalse);
        // База не повинна була закриватися
        verifyNever(() => mockDb.closeConnection());
      },
    );

    test(
      'backupDatabase викликає db.forceCheckpoint() перед роботою з Drive',
      () async {
        // Умова 1: Авторизація успішна (повертаємо фальшивий HTTP клієнт)
        final mockClient = MockHttpClient();
        when(
          () => mockAuthService.getAuthenticatedClient(),
        ).thenAnswer((_) async => mockClient);

        // Умова 2: База даних успішно робить checkpoint (повертаємо нічого - порожню Future)
        when(() => mockDb.forceCheckpoint()).thenAnswer((_) async => {});

        // Спробуємо виконати бекап. Оскільки ми не налаштували відповіді Drive API
        // для mockClient, він видасть помилку під час мережевого запиту. Це нормально!
        await backupService.backupDatabase(mockDb);

        // Головна перевірка: чи був викликаний метод forceCheckpoint перед помилкою?
        verify(() => mockDb.forceCheckpoint()).called(1);
      },
    );
  });
}
