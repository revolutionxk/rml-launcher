// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'os_reduce_motion.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OsReduceMotion)
final osReduceMotionProvider = OsReduceMotionProvider._();

final class OsReduceMotionProvider
    extends $NotifierProvider<OsReduceMotion, bool?> {
  OsReduceMotionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'osReduceMotionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$osReduceMotionHash();

  @$internal
  @override
  OsReduceMotion create() => OsReduceMotion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool?>(value),
    );
  }
}

String _$osReduceMotionHash() => r'406b61d99aa144f803c3bb8a4a9f2ac17212e3d7';

abstract class _$OsReduceMotion extends $Notifier<bool?> {
  bool? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool?, bool?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool?, bool?>,
              bool?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
