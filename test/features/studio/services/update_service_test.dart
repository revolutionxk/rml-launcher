import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

import '../../../support/memory_json_store.dart';
import '../../../support/service_harness.dart';
import '../../../support/studio_fixtures.dart';
import '../../../support/studio_library_fixtures.dart';

void main() {
  late ServiceHarness harness;
  late UpdateService updates;
  late StudioBuild current;
  DateTime now = DateTime.utc(2026, 10, 12, 9);

  setUp(() async {
    harness = await ServiceHarness.start();
    current = await harness.makeBuild(
      'main',
      '0.690.0.1',
      files: <String, String>{
        'ClientSettings/ClientAppSettings.json': '{"FFlagX":true}',
      },
    );
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(managedInstall('main', current: current)),
    );
    now = DateTime.utc(2026, 10, 12, 9);
    updates = harness.updateService(clock: () => now);
  });

  tearDown(() => harness.close());

  StudioInstall main() => harness.library.value.byId('main')!;

  void live(String version) => harness.cdn.live = LiveVersion(
    version: StudioVersion.parse(version),
    guid: 'version-$version',
  );

  String settingsIn(StudioBuild build) => p.join(
    harness.layout.payloadDir(build),
    'ClientSettings',
    'ClientAppSettings.json',
  );

  test('a newer live build is downloaded as ready', () async {
    live('0.691.0.1');
    expect((await updates.checkForUpdates()).isOk, isTrue);
    expect(main().ready!.version.text, '0.691.0.1');
    expect(main().current, current);
    expect(harness.tasks.tasks.first.kind, TaskKind.update);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<UpdateReady>(), hasLength(1));
  });

  test('nothing happens when live is not newer', () async {
    live('0.690.0.1');
    await updates.checkForUpdates();
    expect(harness.installer.requests, isEmpty);
    expect(main().ready, isNull);
  });

  test('pinned and found installs are left alone', () async {
    await harness.library.update(
      (StudioLibrary library) => library
          .upsert(main().copyWith(policy: UpdatePolicy.pinned))
          .upsert(
            foundInstall(
              'roblox-1',
              InstallSource.roblox,
              current: buildAt('/r'),
            ),
          ),
    );
    live('0.691.0.1');
    await updates.checkForUpdates();
    expect(harness.installer.requests, isEmpty);
  });

  test('a newer live build replaces an older ready one', () async {
    live('0.691.0.1');
    await updates.checkForUpdates();
    final StudioBuild older = main().ready!;
    live('0.692.0.1');
    await updates.checkForUpdates();
    expect(main().ready!.version.text, '0.692.0.1');
    expect(Directory(harness.layout.buildDirOf(older)).existsSync(), isFalse);
  });

  test('a focus check waits fifteen minutes between checks', () async {
    live('0.690.0.1');
    await updates.checkIfDue();
    await updates.checkIfDue();
    expect(harness.cdn.liveRequests, 1);
    now = now.add(const Duration(minutes: 16));
    await updates.checkIfDue();
    expect(harness.cdn.liveRequests, 2);
  });

  test('applying moves the carried folders and keeps the old build', () async {
    final StudioBuild older = await harness.makeBuild('main', '0.689.0.1');
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(main().copyWith(previous: older)),
    );
    live('0.691.0.1');
    await updates.checkForUpdates();
    final StudioBuild ready = main().ready!;
    expect((await updates.applyReady('main')).isOk, isTrue);
    expect(main().current, ready);
    expect(main().previous, current);
    expect(main().ready, isNull);
    expect(File(settingsIn(ready)).readAsStringSync(), '{"FFlagX":true}');
    expect(File(settingsIn(current)).existsSync(), isFalse);
    expect(Directory(harness.layout.buildDirOf(older)).existsSync(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<UpdateApplied>(), hasLength(1));
  });

  test('applying waits for Studio to close', () async {
    live('0.691.0.1');
    await updates.checkForUpdates();
    harness.runStudioFrom(harness.layout.studioExecutable(current));
    expect(
      (await updates.applyReady('main')).failureOrNull,
      isA<StudioRunningFailure>(),
    );
    expect(main().current, current);
    expect(File(settingsIn(current)).existsSync(), isTrue);
  });

  test('the update gate can block applying', () async {
    harness.hooks.updateGate = (
      StudioInstall install,
      StudioVersion candidate,
    ) async => const UpdateReview(blockers: <String>['Tracy profiler bridge']);
    live('0.691.0.1');
    await updates.checkForUpdates();
    expect((await updates.review('main')).blockers, <String>[
      'Tracy profiler bridge',
    ]);
    expect(
      (await updates.applyReady('main')).failureOrNull,
      isA<UpdateBlockedFailure>(),
    );
  });

  test('without a ready build there is nothing to apply', () async {
    expect(
      (await updates.applyReady('main')).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('rolling back swaps the builds and brings the folders back', () async {
    live('0.691.0.1');
    await updates.checkForUpdates();
    await updates.applyReady('main');
    final StudioBuild updated = main().current!;
    expect((await updates.rollBack('main')).isOk, isTrue);
    expect(main().current, current);
    expect(main().previous, updated);
    expect(File(settingsIn(current)).readAsStringSync(), '{"FFlagX":true}');
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<RolledBack>(), hasLength(1));
  });

  test('rolling back needs a previous build', () async {
    expect(
      (await updates.rollBack('main')).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test(
    'live equal to the previous build reuses it without a download',
    () async {
      live('0.691.0.1');
      await updates.checkForUpdates();
      await updates.applyReady('main');
      await updates.rollBack('main');
      final StudioBuild rolledFrom = main().previous!;
      await harness.library.update(
        (StudioLibrary library) =>
            library.upsert(main().copyWith(policy: UpdatePolicy.followLive)),
      );
      harness.installer.requests.clear();
      await updates.checkForUpdates();
      expect(harness.installer.requests, isEmpty);
      expect(main().ready, rolledFrom);
      expect(main().previous, isNull);
      expect((await updates.applyReady('main')).isOk, isTrue);
      expect(main().current, rolledFrom);
      expect(Directory(rolledFrom.path).existsSync(), isTrue);
    },
  );

  test('switching to follow live checks at once in the background', () async {
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(main().copyWith(policy: UpdatePolicy.pinned)),
    );
    live('0.691.0.1');
    harness.installer.gate = Completer<void>();
    final Result<void> result = await updates.setPolicy(
      'main',
      UpdatePolicy.followLive,
    );
    expect(result.isOk, isTrue);
    expect(main().policy, UpdatePolicy.followLive);
    await until(() => harness.tasks.isBusy('main'));
    expect(main().ready, isNull);
    harness.installer.gate!.complete();
    await until(() => main().ready != null);
    expect(main().ready!.version.text, '0.691.0.1');
  });

  test('applying is refused while an update task runs', () async {
    harness.installer.gate = Completer<void>();
    live('0.691.0.1');
    final Future<Result<void>> checking = updates.checkForUpdates();
    await Future<void>.delayed(Duration.zero);
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(main().copyWith(ready: current)),
    );
    expect(
      (await updates.applyReady('main')).failureOrNull,
      isA<TaskBusyFailure>(),
    );
    harness.installer.gate!.complete();
    await checking;
  });

  test('rolling back waits for Studio to close', () async {
    live('0.691.0.1');
    await updates.checkForUpdates();
    await updates.applyReady('main');
    harness.runStudioFrom(harness.layout.studioExecutable(main().current!));
    expect(
      (await updates.rollBack('main')).failureOrNull,
      isA<StudioRunningFailure>(),
    );
  });

  test('applying is refused while the previous build runs', () async {
    final StudioBuild older = await harness.makeBuild('main', '0.689.0.1');
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(main().copyWith(previous: older)),
    );
    live('0.691.0.1');
    await updates.checkForUpdates();
    harness.runStudioFrom(harness.layout.studioExecutable(older));
    expect(
      (await updates.applyReady('main')).failureOrNull,
      isA<StudioRunningFailure>(),
    );
    expect(File(settingsIn(current)).existsSync(), isTrue);
    expect(File(settingsIn(main().ready!)).existsSync(), isFalse);
  });

  test('retrying an old failed apply leaves the live build alone', () async {
    harness.hooks.updateGate = (
      StudioInstall install,
      StudioVersion candidate,
    ) async => const UpdateReview(blockers: <String>['blocked']);
    live('0.691.0.1');
    await updates.checkForUpdates();
    expect((await updates.applyReady('main')).isErr, isTrue);
    final String failedId = harness.tasks.tasks
        .firstWhere((StudioTask task) => task.kind == TaskKind.applyUpdate)
        .id;
    harness.hooks.updateGate = (
      StudioInstall install,
      StudioVersion candidate,
    ) async => const UpdateReview();
    expect((await updates.applyReady('main')).isOk, isTrue);
    final StudioBuild applied = main().current!;
    final Result<Object?>? retried = await harness.tasks.retry(failedId);
    expect(retried!.isErr, isTrue);
    expect(main().current, applied);
    expect(File(settingsIn(applied)).readAsStringSync(), '{"FFlagX":true}');
    expect(File(settingsIn(main().previous!)).existsSync(), isFalse);
  });

  test('a failed save keeps the carried files in the new build', () async {
    final FlakyJsonStore store = FlakyJsonStore();
    final LibraryStore flaky = await LibraryStore.open(
      InstallRepository(store),
    );
    await flaky.update(
      (StudioLibrary library) =>
          library.upsert(managedInstall('main', current: current)),
    );
    live('0.691.0.1');
    final UpdateService service = UpdateService(
      library: flaky,
      tasks: harness.tasks,
      fetcher: harness.fetcher,
      layout: harness.layout,
      running: harness.running,
      hooks: harness.hooks,
      events: harness.events,
    );
    await service.checkForUpdates();
    final StudioBuild ready = flaky.value.byId('main')!.ready!;
    store.failWrites = true;
    final Result<void> result = await service.applyReady('main');
    expect(result.isErr, isTrue);
    expect(flaky.value.byId('main')!.current, ready);
    expect(File(settingsIn(ready)).readAsStringSync(), '{"FFlagX":true}');
    expect(File(settingsIn(current)).existsSync(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<UpdateApplied>(), isEmpty);
  });

  test('a Studio started while the gate waits stops the apply', () async {
    final Completer<void> open = Completer<void>();
    harness.hooks.updateGate =
        (StudioInstall install, StudioVersion candidate) async {
          await open.future;
          return const UpdateReview();
        };
    live('0.691.0.1');
    await updates.checkForUpdates();
    final Future<Result<void>> applying = updates.applyReady('main');
    await Future<void>.delayed(Duration.zero);
    harness.runStudioFrom(harness.layout.studioExecutable(current));
    open.complete();
    expect((await applying).failureOrNull, isA<StudioRunningFailure>());
    expect(main().current, current);
    expect(File(settingsIn(current)).existsSync(), isTrue);
  });

  test('rolling back pins the install and checks leave it alone', () async {
    live('0.691.0.1');
    await updates.checkForUpdates();
    await updates.applyReady('main');
    await updates.rollBack('main');
    expect(main().policy, UpdatePolicy.pinned);
    harness.installer.requests.clear();
    await updates.checkForUpdates();
    expect(harness.installer.requests, isEmpty);
    expect(main().ready, isNull);
  });
}

final class FlakyJsonStore implements JsonStore {
  final MemoryJsonStore _inner = MemoryJsonStore();
  bool failWrites = false;

  @override
  Future<Result<JsonMap?>> read(String name) => _inner.read(name);

  @override
  Future<Result<void>> write(String name, JsonMap value) async {
    if (failWrites) {
      return const Result<void>.err(IoFailure(path: 'installs.json'));
    }
    return _inner.write(name, value);
  }
}
