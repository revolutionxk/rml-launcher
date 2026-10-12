import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/file_record.dart';
import 'package:rml_launcher/features/studio/data/install/windows_build_installer.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

import '../../../../support/fixture_server.dart';
import '../../../../support/studio_fixtures.dart';
import '../../../../support/studio_harness.dart';

void main() {
  final StudioVersion version = StudioVersion.parse('0.690.0.6900613');
  const String guid = 'version-test';
  late StudioHarness harness;
  late WindowsBuildInstaller installer;

  setUp(() async {
    harness = await StudioHarness.start(os: HostOs.windows);
    installer = WindowsBuildInstaller(
      cdn: harness.cdn(CdnPlatform.windows),
      downloader: harness.downloader(),
      native: harness.native,
      layout: harness.layout,
      staging: harness.staging(),
    );
  });

  tearDown(() => harness.close());

  Future<Result<InstalledBuild>> install() => harness.runInstall(
    'main',
    (TaskControl control) => installer.install(
      BuildRequest(installId: 'main', version: version, guid: guid),
      control,
    ),
  );

  String built(String relative) => p.joinAll(<String>[
    harness.layout.buildDir('main', version),
    ...relative.split('/'),
  ]);

  test('installs every package where it belongs', () async {
    publishWindowsBuild(harness.server, guid);
    final Result<InstalledBuild> result = await install();
    final InstalledBuild installed = result.valueOrNull!;
    expect(installed.build.path, harness.layout.buildDir('main', version));
    expect(installed.build.version, version);
    expect(installed.build.guid, guid);
    expect(installed.replacedDir, isNull);
    expect(File(built('RobloxStudioBeta.exe')).readAsStringSync(), 'studio');
    expect(
      File(built('content/avatar/faces/y.png')).readAsStringSync(),
      'face',
    );
    expect(File(built('ApplicationConfig/Settings.json')).existsSync(), isTrue);
    expect(File(built('lib.dll')).readAsStringSync(), 'library');
    expect(File(built('AppSettings.xml')).lengthSync(), 111);
    expect(
      File(built('ApplicationConfig/OAuth2Config.json')).lengthSync(),
      642,
    );
    expect(File(built('version.txt')).readAsStringSync(), version.text);
    expect(File(built('version-guid.txt')).readAsStringSync(), guid);
    final BuildMarker marker = (await BuildMarker.read(
      harness.layout.buildDir('main', version),
    ))!;
    expect(marker.binaryTarget, 'WindowsStudio64');
    expect(marker.version, version);
    final FileRecord record = await FileRecord.read(
      harness.layout.buildDir('main', version),
    );
    expect(record.packages['content-avatar.zip']!.files, <String, int>{
      'content/avatar/x.png': 6,
      'content/avatar/faces/y.png': 4,
    });
    expect(
      Directory(harness.layout.stagingDir('main', version)).existsSync(),
      isFalse,
    );
    expect(harness.tasks.tasks.single.state, TaskState.done);
    expect(harness.tasks.tasks.single.progress, 1);
  });

  test('a disk without room stops before downloading', () async {
    publishWindowsBuild(harness.server, guid);
    harness.native.freeBytes = 10;
    final Result<InstalledBuild> result = await install();
    final InsufficientSpaceFailure failure =
        result.failureOrNull! as InsufficientSpaceFailure;
    expect(failure.freeBytes, 10);
    expect(failure.neededBytes, greaterThan(10));
    expect(harness.server.hits('setup/$guid-RobloxApp.zip'), 0);
    expect(
      Directory(harness.layout.stagingDir('main', version)).existsSync(),
      isFalse,
    );
  });

  test(
    'a damaged package fails the install and keeps good downloads',
    () async {
      publishWindowsBuild(
        harness.server,
        guid,
        wrongMd5: <String>{'content-avatar.zip'},
      );
      final Result<InstalledBuild> result = await install();
      expect(result.failureOrNull, isA<IntegrityFailure>());
      expect(
        Directory(harness.layout.stagingDir('main', version)).existsSync(),
        isFalse,
      );
      expect(
        Directory(harness.layout.buildDir('main', version)).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(harness.layout.downloadsDir(version), 'RobloxApp.zip'))
            .existsSync(),
        isTrue,
      );
    },
  );

  test('a dropped package download resumes and the install succeeds', () async {
    publishWindowsBuild(harness.server, guid);
    harness.server.fault('setup/$guid-RobloxApp.zip', const DropFault(20));
    final Result<InstalledBuild> result = await install();
    expect(result.isOk, isTrue);
    expect(File(built('RobloxStudioBeta.exe')).readAsStringSync(), 'studio');
  });

  test('installing a version that is already there replaces it', () async {
    publishWindowsBuild(harness.server, guid);
    await install();
    final Result<InstalledBuild> again = await install();
    expect(
      again.valueOrNull!.replacedDir,
      harness.layout.replacedDir('main', version),
    );
    expect(File(built('RobloxStudioBeta.exe')).existsSync(), isTrue);
  });

  test('cancelling removes the staging folder', () async {
    publishWindowsBuild(harness.server, guid);
    harness.server.fault('setup/$guid-Libraries.zip', const StallFault(5));
    final Future<Result<InstalledBuild>> running = install();
    await until(() => harness.server.hits('setup/$guid-Libraries.zip') > 0);
    harness.tasks.cancel(harness.tasks.tasks.single.id);
    expect((await running).failureOrNull, isA<CancelledFailure>());
    expect(
      Directory(harness.layout.stagingDir('main', version)).existsSync(),
      isFalse,
    );
  });

  test('the runtime files are listed with their exact content', () {
    final Map<String, String> files = WindowsBuildInstaller.runtimeFiles(
      version,
      guid,
    );
    expect(files.keys, <String>[
      'AppSettings.xml',
      'ApplicationConfig/OAuth2Config.json',
      'version.txt',
      'version-guid.txt',
    ]);
    expect(utf8.encode(files['AppSettings.xml']!), hasLength(111));
  });
}
