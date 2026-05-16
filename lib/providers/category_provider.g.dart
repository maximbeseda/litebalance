// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoryNotifier)
const categoryProvider = CategoryNotifierProvider._();

final class CategoryNotifierProvider
    extends $NotifierProvider<CategoryNotifier, CategoryState> {
  const CategoryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryNotifierHash();

  @$internal
  @override
  CategoryNotifier create() => CategoryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryState>(value),
    );
  }
}

String _$categoryNotifierHash() => r'0b826eaafdc2ccd0e35a39c7507108e20e62927e';

abstract class _$CategoryNotifier extends $Notifier<CategoryState> {
  CategoryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CategoryState, CategoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CategoryState, CategoryState>,
              CategoryState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
