// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(googleAuthService)
const googleAuthServiceProvider = GoogleAuthServiceProvider._();

final class GoogleAuthServiceProvider
    extends
        $FunctionalProvider<
          GoogleAuthService,
          GoogleAuthService,
          GoogleAuthService
        >
    with $Provider<GoogleAuthService> {
  const GoogleAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleAuthServiceHash();

  @$internal
  @override
  $ProviderElement<GoogleAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GoogleAuthService create(Ref ref) {
    return googleAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleAuthService>(value),
    );
  }
}

String _$googleAuthServiceHash() => r'0845cb1bad7b4fb92c8e20ee9a568cc325593294';

@ProviderFor(driveBackupService)
const driveBackupServiceProvider = DriveBackupServiceProvider._();

final class DriveBackupServiceProvider
    extends
        $FunctionalProvider<
          DriveBackupService,
          DriveBackupService,
          DriveBackupService
        >
    with $Provider<DriveBackupService> {
  const DriveBackupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driveBackupServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driveBackupServiceHash();

  @$internal
  @override
  $ProviderElement<DriveBackupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DriveBackupService create(Ref ref) {
    return driveBackupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriveBackupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriveBackupService>(value),
    );
  }
}

String _$driveBackupServiceHash() =>
    r'5c688f9715692b0162dc2c0a5cab026b05dadab1';
