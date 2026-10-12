import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/features/studio/domain/running_studio.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/studio_engine.dart';

part 'studio_providers.g.dart';

@Riverpod(keepAlive: true)
StudioEngine studioEngine(Ref ref) =>
    throw UnimplementedError('studioEngine must be overridden at startup');

@Riverpod(keepAlive: true)
Stream<StudioLibrary> studioLibrary(Ref ref) =>
    ref.watch(studioEngineProvider).library.watch();

@Riverpod(keepAlive: true)
Stream<List<StudioTask>> studioTasks(Ref ref) =>
    ref.watch(studioEngineProvider).tasks.watch();

@Riverpod(keepAlive: true)
Stream<List<RunningStudio>> runningStudios(Ref ref) =>
    ref.watch(studioEngineProvider).running.watch();

@Riverpod(keepAlive: true)
Stream<StudioEvent> studioEvents(Ref ref) =>
    ref.watch(studioEngineProvider).events.stream;
