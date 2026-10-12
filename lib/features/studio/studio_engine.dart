import 'dart:ffi';
import 'dart:io';

import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/core/tasks/activity_repository.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/mac_discovery.dart';
import 'package:rml_launcher/features/studio/data/discovery/vinegar.dart';
import 'package:rml_launcher/features/studio/data/discovery/windows_discovery.dart';
import 'package:rml_launcher/features/studio/data/download/download_limiter.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/mac_build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/install/windows_build_installer.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/check_files_service.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';
import 'package:rml_launcher/features/studio/services/install_service.dart';
import 'package:rml_launcher/features/studio/services/launch_service.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';
import 'package:rml_launcher/features/studio/services/studio_lifecycle.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

final class StudioEngine {
  StudioEngine({
    required this.layout,
    required this.library,
    required this.tasks,
    required this.events,
    required this.hooks,
    required this.running,
    required this.installs,
    required this.updates,
    required this.checks,
    required this.discovery,
    required this.launcher,
    required this.lifecycle,
    required this._ownedClient,
  });

  static Future<StudioEngine> create({
    required AppPaths paths,
    required AppSettings settings,
    required JsonStore store,
    required NativeService native,
    required HostOs os,
    required Map<String, String> environment,
    ProcessStarter processes = const SystemProcessStarter(),
    HttpClient? client,
    CdnEndpoints? endpoints,
    Abi? abi,
    DateTime Function()? clock,
  }) async {
    final StudioLayout layout = StudioLayout.resolve(
      paths: paths,
      settings: settings,
      os: os,
    );
    final LibraryStore library = await LibraryStore.open(
      InstallRepository(store),
    );
    final TaskCenter tasks = await TaskCenter.open(
      ActivityRepository(store),
      clock: clock,
    );
    final StudioEvents events = StudioEvents();
    final StudioHooks hooks = StudioHooks();
    final HttpClient http = client ?? createHttpClient();
    final CdnPlatform? platform = CdnPlatform.forHost(os, abi ?? Abi.current());
    final StudioCdn? cdn = platform == null
        ? null
        : RobloxCdn(client: http, platform: platform, endpoints: endpoints);
    final Downloader downloader = Downloader(
      client: http,
      native: native,
      limiter: DownloadLimiter(4),
    );
    final StagingArea staging = StagingArea(layout: layout, native: native);
    final BuildInstaller? installer = cdn == null
        ? null
        : switch (os) {
            HostOs.windows => WindowsBuildInstaller(
              cdn: cdn,
              downloader: downloader,
              native: native,
              layout: layout,
              staging: staging,
              clock: clock,
            ),
            HostOs.macos => MacBuildInstaller(
              cdn: cdn,
              downloader: downloader,
              native: native,
              layout: layout,
              staging: staging,
              clock: clock,
            ),
            HostOs.linux => null,
          };
    final RunningWatcher running = RunningWatcher(
      native: native,
      library: library,
      os: os,
      events: events,
      clock: clock,
    );
    final BuildFetcher fetcher = BuildFetcher(
      tasks: tasks,
      cdn: cdn,
      installer: installer,
      layout: layout,
    );
    final VinegarLocator vinegar = VinegarLocator(
      environment: environment,
      processes: processes,
    );
    final DiscoveryService discovery = DiscoveryService(
      library: library,
      providers: switch (os) {
        HostOs.windows => <DiscoveryProvider>[
          WindowsDiscovery(environment: environment, native: native),
        ],
        HostOs.macos => <DiscoveryProvider>[
          MacDiscovery.standard(
            home: environment['HOME'] ?? '',
            native: native,
            processes: processes,
            studioRoot: layout.root,
          ),
        ],
        HostOs.linux => <DiscoveryProvider>[
          VinegarDiscovery(locator: vinegar, native: native),
        ],
      },
      layout: layout,
      events: events,
    );
    final UpdateService updates = UpdateService(
      library: library,
      tasks: tasks,
      fetcher: fetcher,
      layout: layout,
      running: running,
      hooks: hooks,
      events: events,
      clock: clock,
    );
    return StudioEngine(
      layout: layout,
      library: library,
      tasks: tasks,
      events: events,
      hooks: hooks,
      running: running,
      installs: InstallService(
        library: library,
        tasks: tasks,
        fetcher: fetcher,
        staging: staging,
        layout: layout,
        running: running,
        events: events,
        clock: clock,
      ),
      updates: updates,
      checks: CheckFilesService(
        library: library,
        tasks: tasks,
        fetcher: fetcher,
        downloader: installer == null ? null : downloader,
        native: native,
        layout: layout,
        running: running,
        hooks: hooks,
      ),
      discovery: discovery,
      launcher: LaunchService(
        library: library,
        tasks: tasks,
        layout: layout,
        processes: processes,
        discovery: discovery,
        updates: updates,
        hooks: hooks,
        vinegar: vinegar,
        clock: clock,
      ),
      lifecycle: StudioLifecycle(
        layout: layout,
        discovery: discovery,
        updates: updates,
        running: running,
      ),
      ownedClient: client == null ? http : null,
    );
  }

  final StudioLayout layout;
  final LibraryStore library;
  final TaskCenter tasks;
  final StudioEvents events;
  final StudioHooks hooks;
  final RunningWatcher running;
  final InstallService installs;
  final UpdateService updates;
  final CheckFilesService checks;
  final DiscoveryService discovery;
  final LaunchService launcher;
  final StudioLifecycle lifecycle;
  final HttpClient? _ownedClient;

  Future<void> dispose() async {
    await lifecycle.dispose();
    _ownedClient?.close(force: true);
    await events.close();
    await library.close();
  }
}
