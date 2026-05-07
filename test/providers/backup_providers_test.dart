import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Заміни 'coinflow_app' на реальну назву твого пакета, якщо вона відрізняється
import 'package:coin_flow/providers/backup_providers.dart';
import 'package:coin_flow/services/google_auth_service.dart';
import 'package:coin_flow/services/drive_backup_service.dart';

void main() {
  // Групуємо тести для зручності читання в консолі
  group('Backup Providers Tests', () {
    test('googleAuthServiceProvider створює екземпляр GoogleAuthService', () {
      // 1. Створюємо ізольований контейнер для тестів
      final container = ProviderContainer();

      // 2. Гарантуємо, що контейнер буде знищено після завершення тесту
      // Це звільняє пам'ять
      addTearDown(container.dispose);

      // 3. Зчитуємо значення з нашого провайдера
      final authService = container.read(googleAuthServiceProvider);

      // 4. Перевіряємо, чи має отриманий об'єкт правильний тип
      expect(authService, isA<GoogleAuthService>());
    });

    test('driveBackupServiceProvider створює екземпляр DriveBackupService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Тут Riverpod автоматично підтягне і googleAuthServiceProvider,
      // оскільки driveBackupService залежить від нього.
      final backupService = container.read(driveBackupServiceProvider);

      expect(backupService, isA<DriveBackupService>());
    });
  });
}
