import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/install_service.dart';

import '../../../support/memory_json_store.dart';
import '../../../support/service_harness.dart';
import '../../../support/studio_fixtures.dart';
import '../../../support/studio_library_fixtures.dart';

void main() {
  const InstallLook orange = InstallLook(
    color: IdentityColor.orange,
    monogram: 'M',
  );
  final StudioVersion live = StudioVersion.parse('0.691.0.6910001');
  late ServiceHarness harness;
  late InstallService service;

  Future<void> start({
    HostOs os = HostOs.windows,
    List<StudioInstall> installs = const <StudioInstall>[],
    bool downloads = true,
  }) async {
    harness = await ServiceHarness.start(
      os: os,
      installs: installs,
      downloads: downloads,
    );
    harness.cdn.live = LiveVersion(version: live, guid: 'version-live');
    service = harness.installService();
  }

  tearDown(() => harness.close());

  test('a new install follows live and gets the live build', () async {
    await start();
    final Result<StudioInstall> result = await service.create(
      name: 'Main',
      look: orange,
    );
    final StudioInstall install = result.valueOrNull!;
    expect(install.id, 'main');
    expect(install.policy, UpdatePolicy.followLive);
    expect(install.current!.version, live);
    expect(harness.installer.requests.single.guid, 'version-live');
    expect(harness.library.value.byId('main')!.current, isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.first, isA<InstallAdded>());
    expect(harness.seen.whereType<BuildInstalled>(), hasLength(1));
    expect(harness.tasks.tasks.single.state, TaskState.done);
  });

  test('a new install with a version is pinned to it', () async {
    await start();
    harness.cdn.guids['0.600.0.1'] = 'version-old';
    final Result<StudioInstall> result = await service.create(
      name: 'Legacy',
      look: orange,
      version: StudioVersion.parse('0.600.0.1'),
    );
    expect(result.valueOrNull!.policy, UpdatePolicy.pinned);
    expect(result.valueOrNull!.current!.version.text, '0.600.0.1');
    expect(harness.installer.requests.single.guid, 'version-old');
  });

  test('a library that could not be read refuses new installs', () async {
    await start();
    final LibraryStore refused = LibraryStore(
      InstallRepository(MemoryJsonStore()),
      StudioLibrary.empty,
      loadFailure: const IoFailure(path: 'installs.json'),
    );
    addTearDown(refused.close);
    final InstallService locked = InstallService(
      library: refused,
      tasks: harness.tasks,
      fetcher: harness.fetcher,
      staging: harness.staging,
      layout: harness.layout,
      running: harness.running,
      events: harness.events,
    );
    final Result<StudioInstall> result = await locked.create(
      name: 'Main',
      look: orange,
    );
    expect(result.failureOrNull, same(refused.loadFailure));
    expect(harness.installer.requests, isEmpty);
    expect(Directory(harness.layout.installDir('main')).existsSync(), isFalse);
  });

  test('the same name twice gets two ids', () async {
    await start();
    await service.create(name: 'Main', look: orange);
    final Result<StudioInstall> second = await service.create(
      name: 'Main',
      look: orange,
    );
    expect(second.valueOrNull!.id, 'main-2');
  });

  test('a failed download keeps the install and a retry finishes it', () async {
    await start();
    harness.installer.failWith = const NetworkFailure();
    final Result<StudioInstall> result = await service.create(
      name: 'Main',
      look: orange,
    );
    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(harness.library.value.byId('main')!.current, isNull);
    harness.installer.failWith = null;
    final Result<Object?> retried = await harness.tasks.retry(
      harness.tasks.tasks.first.id,
    )!;
    expect(retried.isOk, isTrue);
    expect(harness.library.value.byId('main')!.current!.version, live);
  });

  test('a cancelled first download removes the install', () async {
    await start();
    harness.installer.gate = Completer<void>();
    final Future<Result<StudioInstall>> pending = service.create(
      name: 'Main',
      look: orange,
    );
    await until(() => harness.tasks.isBusy('main'));
    harness.tasks.cancel(harness.tasks.activeFor('main')!.id);
    expect((await pending).failureOrNull, isA<CancelledFailure>());
    expect(harness.library.value.byId('main'), isNull);
    expect(Directory(harness.layout.installDir('main')).existsSync(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<InstallRemoved>(), hasLength(1));
  });

  test('downloads of an installed version are cleaned up', () async {
    await start();
    final Directory downloads = Directory(harness.layout.downloadsDir(live))
      ..createSync(recursive: true);
    File(p.join(downloads.path, 'RobloxApp.zip')).writeAsStringSync('zip');
    await service.create(name: 'Main', look: orange);
    expect(downloads.existsSync(), isFalse);
  });

  test('systems without downloads refuse new installs', () async {
    await start(os: HostOs.linux, downloads: false);
    final Result<StudioInstall> result = await service.create(
      name: 'Main',
      look: orange,
    );
    expect(result.failureOrNull, isA<UnsupportedFailure>());
    expect(harness.library.value.installs, isEmpty);
  });

  test('uninstall removes the folder and the record', () async {
    await start();
    await service.create(name: 'Main', look: orange);
    expect((await service.uninstall('main')).isOk, isTrue);
    expect(harness.library.value.byId('main'), isNull);
    expect(Directory(harness.layout.installDir('main')).existsSync(), isFalse);
  });

  test('uninstall waits for Studio to close', () async {
    await start();
    final StudioInstall install = (await service.create(
      name: 'Main',
      look: orange,
    )).valueOrNull!;
    harness.runStudioFrom(
      p.join(install.current!.path, 'RobloxStudioBeta.exe'),
    );
    expect(
      (await service.uninstall('main')).failureOrNull,
      isA<StudioRunningFailure>(),
    );
    expect(Directory(install.current!.path).existsSync(), isTrue);
  });

  test('found installs are hidden, not uninstalled', () async {
    await start(
      installs: <StudioInstall>[
        foundInstall('roblox-1', InstallSource.roblox, current: buildAt('/r')),
      ],
    );
    expect(
      (await service.uninstall('roblox-1')).failureOrNull,
      isA<UnsupportedFailure>(),
    );
    await service.hide('roblox-1');
    expect(harness.library.value.visible, isEmpty);
    await service.show('roblox-1');
    expect(harness.library.value.visible, hasLength(1));
  });

  test('edits are saved at once', () async {
    await start();
    await service.create(name: 'Main', look: orange);
    await service.rename('main', 'Principal');
    await service.setLook(
      'main',
      const InstallLook(color: IdentityColor.teal, glyph: 'cube'),
    );
    await service.setPinned('main', pinned: true);
    await service.setDefault('main');
    final StudioInstall install = harness.library.value.byId('main')!;
    expect(install.name, 'Principal');
    expect(install.look.color, IdentityColor.teal);
    expect(install.pinnedInSidebar, isTrue);
    expect(harness.library.value.defaultInstallId, 'main');
    expect(
      (await service.rename('missing', 'x')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('duplicate copies the build into a pinned install', () async {
    await start();
    final StudioBuild build = await harness.makeBuild(
      'main',
      '0.690.0.1',
      files: <String, String>{
        'ClientSettings/ClientAppSettings.json': '{"FFlagX":true}',
      },
    );
    await harness.library.update(
      (library) => library.upsert(managedInstall('main', current: build)),
    );
    final Result<StudioInstall> result = await service.duplicate(
      'main',
      'Main copy',
    );
    final StudioInstall copy = result.valueOrNull!;
    expect(copy.id, 'main-copy');
    expect(copy.policy, UpdatePolicy.pinned);
    expect(copy.look, harness.library.value.byId('main')!.look);
    expect(copy.current!.version.text, '0.690.0.1');
    expect(
      File(
        p.join(copy.current!.path, 'ClientSettings', 'ClientAppSettings.json'),
      ).readAsStringSync(),
      '{"FFlagX":true}',
    );
    expect(
      BuildMarker.existsIn(harness.layout.buildDirOf(copy.current!)),
      isTrue,
    );
    expect(harness.tasks.tasks.first.kind, TaskKind.duplicate);
  });

  test('duplicate on macos copies the bundle of a found install', () async {
    await start(os: HostOs.macos);
    final String bundle = p.join(
      harness.dir.path,
      'Applications',
      'RobloxStudio.app',
    );
    File(p.join(bundle, 'Contents', 'MacOS', 'RobloxStudio'))
      ..createSync(recursive: true)
      ..writeAsStringSync('studio');
    await harness.library.update(
      (library) => library.upsert(
        foundInstall(
          'mac-1',
          InstallSource.macBundle,
          current: buildAt(bundle, version: '0.700.1'),
        ),
      ),
    );
    final StudioInstall copy = (await service.duplicate(
      'mac-1',
      'Copy',
    )).valueOrNull!;
    expect(p.basename(copy.current!.path), 'RobloxStudio.app');
    expect(
      File(harness.layout.studioExecutable(copy.current!)).readAsStringSync(),
      'studio',
    );
  });

  test('simultaneous creates with one name get distinct ids', () async {
    await start();
    final List<Result<StudioInstall>> results = await Future.wait(
      <Future<Result<StudioInstall>>>[
        service.create(name: 'Main', look: orange),
        service.create(name: 'Main', look: orange),
      ],
    );
    expect(results.every((Result<StudioInstall> r) => r.isOk), isTrue);
    expect(
      results.map((Result<StudioInstall> r) => r.valueOrNull!.id).toSet(),
      <String>{'main', 'main-2'},
    );
  });

  test('a folder already in the root is never reused or deleted', () async {
    await start();
    final File game = File(p.join(harness.layout.root, 'Steam', 'game.bin'))
      ..createSync(recursive: true);
    harness.installer.gate = Completer<void>();
    final Future<Result<StudioInstall>> pending = service.create(
      name: 'Steam',
      look: orange,
    );
    await until(() => harness.library.value.installs.isNotEmpty);
    final String id = harness.library.value.installs.single.id;
    expect(id, isNot('steam'));
    await until(() => harness.tasks.isBusy(id));
    harness.tasks.cancel(harness.tasks.activeFor(id)!.id);
    await pending;
    expect(game.existsSync(), isTrue);
  });

  test('an unreadable root fails the create and adds nothing', () async {
    await start();
    final Directory root = Directory(harness.layout.root)
      ..createSync(recursive: true);
    Process.runSync('chmod', <String>['000', root.path]);
    addTearDown(() => Process.runSync('chmod', <String>['755', root.path]));
    final Result<StudioInstall> result = await service.create(
      name: 'Main',
      look: orange,
    );
    expect(result.failureOrNull, isA<IoFailure>());
    expect(harness.library.value.installs, isEmpty);
  }, skip: Platform.isWindows);

  test('a retry of an uninstalled install cannot be run', () async {
    await start();
    harness.installer.failWith = const NetworkFailure();
    await service.create(name: 'Main', look: orange);
    final String failed = harness.tasks.tasks.first.id;
    await service.uninstall('main');
    expect(harness.tasks.retry(failed), isNull);
  });
}
