import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/tasks/activity_repository.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/vinegar.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';
import 'package:rml_launcher/features/studio/services/install_service.dart';
import 'package:rml_launcher/features/studio/services/launch_service.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

import 'fake_build_installer.dart';
import 'fake_native_service.dart';
import 'fake_process_starter.dart';
import 'fake_studio_cdn.dart';
import 'memory_json_store.dart';
import 'studio_library_fixtures.dart';

final class ServiceHarness {
  ServiceHarness._({
    required this.dir,
    required this.layout,
    required this.library,
    required this.tasks,
    required this.native,
    required this.events,
    required this.seen,
    required this.running,
    required this.cdn,
    required this.installer,
    required this.fetcher,
    required this.staging,
    required this.hooks,
  });

  static Future<ServiceHarness> start({
    HostOs os = HostOs.windows,
    List<StudioInstall> installs = const <StudioInstall>[],
    bool downloads = true,
  }) async {
    final Directory dir = await Directory.systemTemp.createTemp(
      'rml services Ação ',
    );
    final StudioLayout layout = StudioLayout(
      root: p.join(dir.path, 'Studio'),
      os: os,
    );
    final LibraryStore library = await libraryWith(installs);
    final TaskCenter tasks = TaskCenter(
      history: ActivityRepository(MemoryJsonStore()),
    );
    final FakeNativeService native = FakeNativeService(realFiles: true);
    final StudioEvents events = StudioEvents();
    final List<StudioEvent> seen = <StudioEvent>[];
    events.stream.listen(seen.add);
    final FakeStudioCdn cdn = FakeStudioCdn(
      platform: os == HostOs.macos ? CdnPlatform.macArm64 : CdnPlatform.windows,
    );
    final FakeBuildInstaller installer = FakeBuildInstaller(layout);
    return ServiceHarness._(
      dir: dir,
      layout: layout,
      library: library,
      tasks: tasks,
      native: native,
      events: events,
      seen: seen,
      running: RunningWatcher(
        native: native,
        library: library,
        os: os,
        events: events,
      ),
      cdn: cdn,
      installer: installer,
      fetcher: BuildFetcher(
        tasks: tasks,
        cdn: downloads ? cdn : null,
        installer: downloads ? installer : null,
        layout: layout,
      ),
      staging: StagingArea(layout: layout, native: native),
      hooks: StudioHooks(),
    );
  }

  final Directory dir;
  final StudioLayout layout;
  final LibraryStore library;
  final TaskCenter tasks;
  final FakeNativeService native;
  final StudioEvents events;
  final List<StudioEvent> seen;
  final RunningWatcher running;
  final FakeStudioCdn cdn;
  final FakeBuildInstaller installer;
  final BuildFetcher fetcher;
  final StagingArea staging;
  final StudioHooks hooks;

  InstallService installService() => InstallService(
    library: library,
    tasks: tasks,
    fetcher: fetcher,
    staging: staging,
    layout: layout,
    running: running,
    events: events,
  );

  UpdateService updateService({DateTime Function()? clock}) => UpdateService(
    library: library,
    tasks: tasks,
    fetcher: fetcher,
    layout: layout,
    running: running,
    hooks: hooks,
    events: events,
    clock: clock,
  );

  LaunchService launchService(
    FakeProcessStarter processes, {
    Map<String, String> environment = const <String, String>{},
  }) => LaunchService(
    library: library,
    tasks: tasks,
    layout: layout,
    processes: processes,
    discovery: DiscoveryService(
      library: library,
      providers: const <DiscoveryProvider>[],
      layout: layout,
      events: events,
    ),
    updates: updateService(),
    hooks: hooks,
    vinegar: VinegarLocator(environment: environment, processes: processes),
  );

  void runStudioFrom(String path, {int pid = 100}) => native.processes =
      <NativeProcess>[...native.processes, NativeProcess(pid: pid, path: path)];

  Future<StudioBuild> makeBuild(
    String installId,
    String version, {
    Map<String, String> files = const <String, String>{},
  }) async {
    final StudioVersion parsed = StudioVersion.parse(version);
    final String dir = layout.buildDir(installId, parsed);
    final StudioBuild build = buildAt(
      layout.buildPathIn(dir),
      version: version,
    );
    final File executable = File(layout.studioExecutable(build));
    await executable.parent.create(recursive: true);
    await executable.writeAsString('studio $version');
    for (final MapEntry<String, String> file in files.entries) {
      final File target = File(
        p.joinAll(<String>[layout.payloadDir(build), ...file.key.split('/')]),
      );
      await target.parent.create(recursive: true);
      await target.writeAsString(file.value);
    }
    await BuildMarker(
      version: parsed,
      guid: build.guid,
      binaryTarget: 'Fake',
      installedAt: build.installedAt,
    ).write(dir);
    return build;
  }

  Future<void> close() async {
    await running.dispose();
    await events.close();
    await library.close();
    await dir.delete(recursive: true);
  }
}
