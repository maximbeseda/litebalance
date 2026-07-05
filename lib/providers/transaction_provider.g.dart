// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TransactionNotifier)
const transactionProvider = TransactionNotifierProvider._();

final class TransactionNotifierProvider
    extends $AsyncNotifierProvider<TransactionNotifier, TransactionState> {
  const TransactionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionNotifierHash();

  @$internal
  @override
  TransactionNotifier create() => TransactionNotifier();
}

String _$transactionNotifierHash() =>
    r'f201d23aa3868591c6cb291ca3018d2a7cb6f751';

abstract class _$TransactionNotifier extends $AsyncNotifier<TransactionState> {
  FutureOr<TransactionState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<TransactionState>, TransactionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TransactionState>, TransactionState>,
              AsyncValue<TransactionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
