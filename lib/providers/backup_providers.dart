import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/google_auth_service.dart';
import '../services/drive_backup_service.dart';

part 'backup_providers.g.dart';

@Riverpod(keepAlive: true)
GoogleAuthService googleAuthService(Ref ref) {
  return GoogleAuthService();
}

@Riverpod(keepAlive: true)
DriveBackupService driveBackupService(Ref ref) {
  final auth = ref.watch(googleAuthServiceProvider);
  return DriveBackupService(auth);
}
