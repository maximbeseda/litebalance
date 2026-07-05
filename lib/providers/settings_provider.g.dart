// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrencyRepo)
const currencyRepoProvider = CurrencyRepoProvider._();

final class CurrencyRepoProvider
    extends $NotifierProvider<CurrencyRepo, CurrencyRepository> {
  const CurrencyRepoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencyRepoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencyRepoHash();

  @$internal
  @override
  CurrencyRepo create() => CurrencyRepo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrencyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrencyRepository>(value),
    );
  }
}

String _$currencyRepoHash() => r'c37193371090f5eceb513d8f0a911dee0e3f3cc6';

abstract class _$CurrencyRepo extends $Notifier<CurrencyRepository> {
  CurrencyRepository build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CurrencyRepository, CurrencyRepository>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurrencyRepository, CurrencyRepository>,
              CurrencyRepository,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(SettingsNotifier)
const settingsProvider = SettingsNotifierProvider._();

final class SettingsNotifierProvider
    extends $NotifierProvider<SettingsNotifier, SettingsState> {
  const SettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsNotifierHash();

  @$internal
  @override
  SettingsNotifier create() => SettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsState>(value),
    );
  }
}

String _$settingsNotifierHash() => r'685f8740a0905530551910add69fb740bb666009';

abstract class _$SettingsNotifier extends $Notifier<SettingsState> {
  SettingsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SettingsState, SettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SettingsState, SettingsState>,
              SettingsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
