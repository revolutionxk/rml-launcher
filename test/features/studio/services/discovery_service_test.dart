import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';

import '../../../support/service_harness.dart';
import '../../../support/studio_library_fixtures.dart';

final class FakeProvider implements DiscoveryProvider {
  FakeProvider(this.sources);

  @override
  final Set<InstallSource> sources;

  List<DiscoveredInstall> installs = <DiscoveredInstall>[];
  StateError? error;

  @override
  Future<List<DiscoveredInstall>> scan() async {
    final StateError? failure = error;
    if (failure != null) {
      throw failure;
    }
    return installs;
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
