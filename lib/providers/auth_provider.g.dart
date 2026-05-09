// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthController)
const authControllerProvider = AuthControllerProvider._();

final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, GoogleSignInAccount?> {
  const AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'ac039e59cfb81bc3c07c9957aa7e81f2dba1ca7c';

abstract class _$AuthController extends $AsyncNotifier<GoogleSignInAccount?> {
  FutureOr<GoogleSignInAccount?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<GoogleSignInAccount?>, GoogleSignInAccount?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<GoogleSignInAccount?>,
                GoogleSignInAccount?
              >,
              AsyncValue<GoogleSignInAccount?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
