import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/mac_build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/windows_build_installer.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/check_files_service.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';

import '../../../support/fixture_server.dart';
import '../../../support/studio_fixtures.dart';
import '../../../support/studio_harness.dart';
import '../../../support/studio_library_fixtures.dart';

void main() {
  final StudioVersion version = StudioVersion.parse('0.690.0.6900613');
  const String guid = 'version-check';
  late StudioHarness harness;
  late LibraryStore library;
  late CheckFilesService service;
  late StudioBuild installed;

  Future<void> start(HostOs os) async {
    harness = await StudioHarness.start(os: os);
    final BuildInstaller installer = os == HostOs.macos
        ? MacBuildInstaller(
            cdn: harness.cdn(CdnPlatform.macArm64),
            downloader: harness.downloader(),
            native: harness.native,
            layout: harness.layout,
            staging: harness.staging(),
          )
        : WindowsBuildInstaller(
            cdn: harness.cdn(CdnPlatform.windows),
            downloader: harness.downloader(),
            native: harness.native,
            layout: harness.layout,
            staging: harness.staging(),
          );
    if (os == HostOs.macos) {
      publishMacBuild(harness.server, guid);
      publishLive(harness.server, 'MacStudio', version.text, guid);
    } else {
      publishWindowsBuild(harness.server, guid);
    }
    installed = (await harness.runInstall(
      'main',
      (TaskControl control) => installer.install(
        BuildRequest(installId: 'main', version: version, guid: guid),
        control,
      ),
    )).valueOrNull!.build;
    final Directory downloads = Directory(harness.layout.downloadsDir(version));
    if (downloads.existsSync()) {
      downloads.deleteSync(recursive: true);
    }
    library = await libraryWith(<StudioInstall>[
      managedInstall('main', current: installed),
    ]);
    final StudioHooks hooks = StudioHooks();
    service = CheckFilesService(
      library: library,
      tasks: harness.tasks,
      fetcher: BuildFetcher(
        tasks: harness.tasks,
        cdn: harness.cdn(
          os == HostOs.macos ? CdnPlatform.macArm64 : CdnPlatform.windows,
        ),
        installer: installer,
        layout: harness.layout,
      ),
      downloader: harness.downloader(),
      native: harness.native,
      layout: harness.layout,
      running: RunningWatcher(
        native: harness.native,
        library: library,
        os: os,
        events: StudioEvents(),
      ),
      hooks: hooks,
    );
  }

  tearDown(() async {
    await library.close();
    await harness.close();
  });

  String file(String relative) =>
      p.joinAll(<String>[installed.path, ...relative.split('/')]);

  test('a healthy build needs nothing', () async {
    await start(HostOs.windows);
    final CheckReport report = (await service.check('main')).valueOrNull!;
    expect(report.clean, isTrue);
    expect(harness.server.hits('setup/$guid-RobloxApp.zip'), 1);
  });

  test('only damaged packages are downloaded again', () async {
    await start(HostOs.windows);
    File(file('content/avatar/faces/y.png')).deleteSync();
    File(file('AppSettings.xml')).writeAsStringSync('<Settings/>');
    final CheckReport report = (await service.check('main')).valueOrNull!;
    expect(report.repairedPackages, <String>['content-avatar.zip']);
    expect(report.rewrittenFiles, <String>['AppSettings.xml']);
    expect(File(file('content/avatar/faces/y.png')).readAsStringSync(), 'face');
    expect(File(file('AppSettings.xml')).lengthSync(), 111);
    expect(harness.server.hits('setup/$guid-content-avatar.zip'), 2);
    expect(harness.server.hits('setup/$guid-RobloxApp.zip'), 1);
    expect(
      Directory(harness.layout.downloadsDir(version)).existsSync(),
      isFalse,
    );
  });

  test('a file with the wrong size counts as damaged', () async {
    await start(HostOs.windows);
    File(file('RobloxStudioBeta.exe')).writeAsStringSync('tampered!');
    final CheckReport report = (await service.check('main')).valueOrNull!;
    expect(report.repairedPackages, <String>['RobloxApp.zip']);
    expect(File(file('RobloxStudioBeta.exe')).readAsStringSync(), 'studio');
  });

  test('a corrupted runtime file does not block the repair', () async {
    await start(HostOs.windows);
    File(file('content/avatar/faces/y.png')).deleteSync();
    File(file('AppSettings.xml'))
        .writeAsBytesSync(<int>[0xFF, 0xFE, 0x3C, 0x00]);
    final CheckReport report = (await service.check('main')).valueOrNull!;
    expect(report.repairedPackages, <String>['content-avatar.zip']);
    expect(report.rewrittenFiles, <String>['AppSettings.xml']);
    expect(File(file('AppSettings.xml')).lengthSync(), 111);
    expect(File(file('content/avatar/faces/y.png')).existsSync(), isTrue);
  });

  test('a Studio that starts during the repair stops it', () async {
    await start(HostOs.windows);
    File(file('content/avatar/faces/y.png')).deleteSync();
    harness.server.fault('setup/$guid-content-avatar.zip', const DropFault(20));
    final Future<Result<CheckReport>> running = service.check('main');
    await until(
      () => harness.server.hits('setup/$guid-content-avatar.zip') > 0,
    );
    harness.native.processes = <NativeProcess>[
      NativeProcess(pid: 5, path: file('RobloxStudioBeta.exe')),
    ];
    expect((await running).failureOrNull, isA<StudioRunningFailure>());
    expect(File(file('content/avatar/faces/y.png')).existsSync(), isFalse);
  });

  test('checking waits for Studio to close', () async {
    await start(HostOs.windows);
    harness.native.processes = <NativeProcess>[
      NativeProcess(pid: 5, path: file('RobloxStudioBeta.exe')),
    ];
    expect(
      (await service.check('main')).failureOrNull,
      isA<StudioRunningFailure>(),
    );
  });

  test('a mac bundle without its executable is installed again', () async {
    await start(HostOs.macos);
    final String settings = p.join(
      harness.layout.payloadDir(installed),
      'ClientSettings',
      'ClientAppSettings.json',
    );
    File(settings)
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    File(harness.layout.studioExecutable(installed)).deleteSync();
    final Result<CheckReport> result = await service.check('main');
    expect(result.valueOrNull!.reinstalled, isTrue);
    final StudioBuild current = library.value.byId('main')!.current!;
    expect(File(harness.layout.studioExecutable(current)).existsSync(), isTrue);
    expect(File(settings).readAsStringSync(), '{}');
    expect(
      Directory(harness.layout.replacedDir('main', version)).existsSync(),
      isFalse,
    );
  });

  test('a healthy mac bundle needs nothing', () async {
    await start(HostOs.macos);
    expect((await service.check('main')).valueOrNull!.clean, isTrue);
  });
}
