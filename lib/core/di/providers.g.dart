// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDependencies)
final appDependenciesProvider = AppDependenciesProvider._();

final class AppDependenciesProvider
    extends
        $FunctionalProvider<AppDependencies, AppDependencies, AppDependencies>
    with $Provider<AppDependencies> {
  AppDependenciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDependenciesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDependenciesHash();

  @$internal
  @override
  $ProviderElement<AppDependencies> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDependencies create(Ref ref) {
    return appDependencies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDependencies value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDependencies>(value),
    );
  }
}

String _$appDependenciesHash() => r'dc9f1075a63063298e1e598956267b34f845d6f1';

@ProviderFor(windowChrome)
final windowChromeProvider = WindowChromeProvider._();

final class WindowChromeProvider
    extends $FunctionalProvider<WindowChrome, WindowChrome, WindowChrome>
    with $Provider<WindowChrome> {
  WindowChromeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowChromeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowChromeHash();

  @$internal
  @override
  $ProviderElement<WindowChrome> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WindowChrome create(Ref ref) {
    return windowChrome(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WindowChrome value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WindowChrome>(value),
    );
  }
}

String _$windowChromeHash() => r'c344c7f1d7c06d0a428c2f493c66fbd9bbdaa4fc';

@ProviderFor(nativeService)
final nativeServiceProvider = NativeServiceProvider._();

final class NativeServiceProvider
    extends $FunctionalProvider<NativeService, NativeService, NativeService>
    with $Provider<NativeService> {
  NativeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nativeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nativeServiceHash();

  @$internal
  @override
  $ProviderElement<NativeService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NativeService create(Ref ref) {
    return nativeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NativeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NativeService>(value),
    );
  }
}

String _$nativeServiceHash() => r'be20be7af18ea40cc83308d8166a156cb4baf352';
