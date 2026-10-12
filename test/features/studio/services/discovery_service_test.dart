import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/mac_discovery.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';

import '../../../support/fake_process_starter.dart';
import '../../../support/memory_json_store.dart';
import '../../../support/service_harness.dart';
import '../../../support/studio_library_fixtures.dart';

final class FakeProvider implements DiscoveryProvider {
  FakeProvider(this.sources);

  @override
  final Set<InstallSource> sources;

  List<DiscoveredInstall> installs = <DiscoveredInstall>[];
  Set<String> unreadable = <String>{};
  StateError? error;

  @override
  Future<DiscoveryScan> scan() async {
    final StateError? failure = error;
    if (failure != null) {
      throw failure;
    }
    return DiscoveryScan(found: installs, unreadable: unreadable);
  }
}

DiscoveredInstall bloxstrap(String folder) => DiscoveredInstall(
  id: 'bloxstrap-1',
  source: InstallSource.bloxstrap,
  name: 'Bloxstrap',
  build: buildAt('/b/Versions/$folder'),
);

void main() {
  late ServiceHarness harness;
  late FakeProvider windows;
  late DiscoveryService discovery;

  setUp(() async {
    harness = await ServiceHarness.start();
    windows = FakeProvider(<InstallSource>{
      InstallSource.roblox,
      InstallSource.bloxstrap,
    });
    discovery = DiscoveryService(
      library: harness.library,
      providers: <DiscoveryProvider>[windows],
      layout: harness.layout,
      events: harness.events,
    );
  });

  tearDown(() => harness.close());

  StudioLibrary library() => harness.library.value;

  test('found installs are added once', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    await discovery.refresh();
    await discovery.refresh();
    final StudioInstall install = library().byId('bloxstrap-1')!;
    expect(install.kind, InstallKind.found);
    expect(install.name, 'Bloxstrap');
    expect(install.look.color, IdentityColor.violet);
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<InstallAdded>(), hasLength(1));
  });

  test('a new version folder moves the install and says so', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    await discovery.refresh();
    await harness.library.update(
      (StudioLibrary current) => current.upsert(
        current.byId('bloxstrap-1')!.copyWith(name: 'My Bloxstrap'),
      ),
    );
    windows.installs = <DiscoveredInstall>[bloxstrap('version-b')];
    await discovery.refresh();
    final StudioInstall install = library().byId('bloxstrap-1')!;
    expect(install.current!.path, '/b/Versions/version-b');
    expect(install.name, 'My Bloxstrap');
    await Future<void>.delayed(Duration.zero);
    final FoundBuildChanged changed = harness.seen
        .whereType<FoundBuildChanged>()
        .single;
    expect(changed.from.path, '/b/Versions/version-a');
    expect(changed.to.path, '/b/Versions/version-b');
  });

  test('a vanished install is removed but stays hidden', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    await discovery.refresh();
    await harness.library.update(
      (StudioLibrary current) => current.hide('bloxstrap-1'),
    );
    windows.installs = <DiscoveredInstall>[];
    await discovery.refresh();
    expect(library().byId('bloxstrap-1'), isNull);
    expect(library().hiddenFoundIds, contains('bloxstrap-1'));
  });

  test('a failing provider keeps what it found before', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    await discovery.refresh();
    windows.error = StateError('registry exploded');
    await discovery.refresh();
    expect(library().byId('bloxstrap-1'), isNotNull);
  });

  test('an unreadable install is neither removed nor changed', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    await discovery.refresh();
    windows
      ..installs = <DiscoveredInstall>[]
      ..unreadable = <String>{'bloxstrap-1'};
    await discovery.refresh();
    windows
      ..installs = <DiscoveredInstall>[bloxstrap('version-b')]
      ..unreadable = <String>{'bloxstrap-1'};
    await discovery.refresh();
    expect(
      library().byId('bloxstrap-1')!.current!.path,
      '/b/Versions/version-a',
    );
    await Future<void>.delayed(Duration.zero);
    expect(harness.seen.whereType<InstallRemoved>(), isEmpty);
    expect(harness.seen.whereType<FoundBuildChanged>(), isEmpty);
  });

  test('overlapping refreshes share one scan', () async {
    windows.installs = <DiscoveredInstall>[bloxstrap('version-a')];
    final Future<void> first = discovery.refresh();
    final Future<void> second = discovery.refresh();
    expect(identical(first, second), isTrue);
    await first;
  });

  test('an unreachable studio root clears nothing', () async {
    final StudioBuild good = await harness.makeBuild('main', '0.690.0.1');
    await harness.library.update(
      (StudioLibrary current) =>
          current.upsert(managedInstall('main', current: good)),
    );
    Directory(harness.layout.root).deleteSync(recursive: true);
    await discovery.refresh();
    expect(library().byId('main')!.current, good);
  });

  group('macos bundles', () {
    late FakeProcessStarter processes;

    setUp(() => processes = FakeProcessStarter());

    String studioBundle(String name) {
      final String bundle = p.join(harness.dir.path, name, 'RobloxStudio.app');
      File(p.join(bundle, 'Contents', 'MacOS', 'RobloxStudio'))
        ..createSync(recursive: true)
        ..writeAsStringSync('bin');
      harness.native.executables[bundle] = const ExecutableInfo(
        identifier: 'com.roblox.RobloxStudio',
        version: '0.700.1',
        executable: 'RobloxStudio',
      );
      return bundle;
    }

    void spotlight({int exitCode = 0, String found = ''}) =>
        processes.outputs['mdfind ${MacDiscovery.spotlightQuery}'] =
            ProcessOutput(exitCode: exitCode, stdout: found);

    DiscoveryService macDiscovery(
      LibraryStore library, {
      List<String> searchPaths = const <String>[],
    }) => DiscoveryService(
      library: library,
      providers: <DiscoveryProvider>[
        MacDiscovery(
          searchPaths: searchPaths,
          native: harness.native,
          processes: processes,
          studioRoot: harness.layout.root,
        ),
      ],
      layout: harness.layout,
      events: harness.events,
    );

    Future<StudioInstall> renamed(String bundle) async {
      final String id = foundInstallId(InstallSource.macBundle, bundle);
      await harness.library.update(
        (StudioLibrary current) =>
            current.upsert(current.byId(id)!.copyWith(name: 'Mine')),
      );
      return library().byId(id)!;
    }

    test('a failed spotlight search keeps the bundles it found', () async {
      final String bundle = studioBundle('Elsewhere');
      final DiscoveryService discovery = macDiscovery(harness.library);
      spotlight(found: '$bundle\n');
      await discovery.refresh();
      final StudioInstall before = await renamed(bundle);
      spotlight(exitCode: 1);
      await discovery.refresh();
      final StudioInstall after = library().byId(before.id)!;
      expect(after.name, 'Mine');
      expect(after.current, before.current);
      await Future<void>.delayed(Duration.zero);
      expect(harness.seen.whereType<InstallRemoved>(), isEmpty);
    });

    test('a bundle whose info cannot be read keeps its install', () async {
      final String bundle = studioBundle('Applications');
      final DiscoveryService discovery = macDiscovery(
        harness.library,
        searchPaths: <String>[bundle],
      );
      spotlight();
      await discovery.refresh();
      final StudioInstall before = await renamed(bundle);
      harness.native.executables.remove(bundle);
      await discovery.refresh();
      final StudioInstall after = library().byId(before.id)!;
      expect(after.name, 'Mine');
      expect(after.current, before.current);
      await Future<void>.delayed(Duration.zero);
      expect(harness.seen.whereType<InstallRemoved>(), isEmpty);
    });

    test('a refresh that finds nothing new saves nothing', () async {
      final String bundle = studioBundle('Applications');
      final MemoryJsonStore store = MemoryJsonStore();
      final LibraryStore first = await libraryWith(
        const <StudioInstall>[],
        store: store,
      );
      spotlight();
      await macDiscovery(first, searchPaths: <String>[bundle]).refresh();
      expect(first.value.installs, hasLength(1));
      final int writes = store.writes;
      await macDiscovery(first, searchPaths: <String>[bundle]).refresh();
      expect(store.writes, writes);
      await first.close();
      final LibraryStore reopened = await LibraryStore.open(
        InstallRepository(store),
      );
      addTearDown(reopened.close);
      await macDiscovery(reopened, searchPaths: <String>[bundle]).refresh();
      expect(reopened.value.installs, hasLength(1));
      expect(store.writes, writes);
    });
  });

  test('a managed build without its marker is cleared', () async {
    final StudioBuild good = await harness.makeBuild('main', '0.690.0.1');
    final StudioBuild gone = await harness.makeBuild('main', '0.689.0.1');
    Directory(harness.layout.buildDirOf(gone)).deleteSync(recursive: true);
    await harness.library.update(
      (StudioLibrary current) =>
          current.upsert(managedInstall('main', current: good, previous: gone)),
    );
    await discovery.refresh();
    expect(library().byId('main')!.current, good);
    expect(library().byId('main')!.previous, isNull);
  });
}
