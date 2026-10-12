// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(studioEngine)
final studioEngineProvider = StudioEngineProvider._();

final class StudioEngineProvider
    extends $FunctionalProvider<StudioEngine, StudioEngine, StudioEngine>
    with $Provider<StudioEngine> {
  StudioEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioEngineHash();

  @$internal
  @override
  $ProviderElement<StudioEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StudioEngine create(Ref ref) {
    return studioEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioEngine>(value),
    );
  }
}

String _$studioEngineHash() => r'a8ffb8adde29aea2ff667113b02735fef9733e18';

@ProviderFor(studioLibrary)
final studioLibraryProvider = StudioLibraryProvider._();

final class StudioLibraryProvider
    extends
        $FunctionalProvider<
          AsyncValue<StudioLibrary>,
          StudioLibrary,
          Stream<StudioLibrary>
        >
    with $FutureModifier<StudioLibrary>, $StreamProvider<StudioLibrary> {
  StudioLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioLibraryHash();

  @$internal
  @override
  $StreamProviderElement<StudioLibrary> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StudioLibrary> create(Ref ref) {
    return studioLibrary(ref);
  }
}

String _$studioLibraryHash() => r'c2b68e601264c91fb246e1a287be64273497abec';

@ProviderFor(studioTasks)
final studioTasksProvider = StudioTasksProvider._();

final class StudioTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StudioTask>>,
          List<StudioTask>,
          Stream<List<StudioTask>>
        >
    with $FutureModifier<List<StudioTask>>, $StreamProvider<List<StudioTask>> {
  StudioTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioTasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<StudioTask>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StudioTask>> create(Ref ref) {
    return studioTasks(ref);
  }
}

String _$studioTasksHash() => r'18cc3c3839e7c8613899a71a80114938bc157ead';

@ProviderFor(runningStudios)
final runningStudiosProvider = RunningStudiosProvider._();

final class RunningStudiosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RunningStudio>>,
          List<RunningStudio>,
          Stream<List<RunningStudio>>
        >
    with
        $FutureModifier<List<RunningStudio>>,
        $StreamProvider<List<RunningStudio>> {
  RunningStudiosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningStudiosProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningStudiosHash();

  @$internal
  @override
  $StreamProviderElement<List<RunningStudio>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RunningStudio>> create(Ref ref) {
    return runningStudios(ref);
  }
}

String _$runningStudiosHash() => r'47b00305842ae0cecc2512122f62c41791dc6138';

@ProviderFor(studioEvents)
final studioEventsProvider = StudioEventsProvider._();

final class StudioEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<StudioEvent>,
          StudioEvent,
          Stream<StudioEvent>
        >
    with $FutureModifier<StudioEvent>, $StreamProvider<StudioEvent> {
  StudioEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioEventsHash();

  @$internal
  @override
  $StreamProviderElement<StudioEvent> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StudioEvent> create(Ref ref) {
    return studioEvents(ref);
  }
}

String _$studioEventsHash() => r'b7582b8946f3b8276f69f00136d3de09c9ce31e9';
