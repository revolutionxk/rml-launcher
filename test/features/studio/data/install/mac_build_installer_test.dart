import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/mac_build_installer.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

import '../../../../support/studio_fixtures.dart';
import '../../../../support/studio_harness.dart';

void main() {
  final StudioVersion version = StudioVersion.parse('0.690.0.6900613');
  const String guid = 'version-mac';
  const String archivePath = 'setup/mac/arm64/$guid-RobloxStudioApp.zip';
  late StudioHarness harness;
  late MacBuildInstaller installer;

  setUp(() async {
    harness = await StudioHarness.start(os: HostOs.macos);
    installer = MacBuildInstaller(
      cdn: harness.cdn(CdnPlatform.macArm64),
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

  String buildDir() => harness.layout.buildDir('main', version);

  test('installs the app bundle with the marker beside it', () async {
    publishMacBuild(harness.server, guid);
    final InstalledBuild installed = (await install()).valueOrNull!;
    expect(installed.build.path, p.join(buildDir(), 'RobloxStudio.app'));
    expect(
      File(p.join(installed.build.path, 'Contents', 'MacOS', 'RobloxStudio'))
          .readAsStringSync(),
      'studio',
    );
    expect(BuildMarker.existsIn(buildDir()), isTrue);
    expect((await BuildMarker.read(buildDir()))!.binaryTarget, 'MacStudio');
    expect(
      File(p.join(buildDir(), 'version.txt')).readAsStringSync(),
      version.text,
    );
    expect(
      File(p.join(buildDir(), 'version-guid.txt')).readAsStringSync(),
      guid,
    );
    expect(harness.server.requests.first.method, 'HEAD');
  });

  test('an etag that does not match fails the install', () async {
    final Uint8List zip = zipOf(macFiles);
    harness.server.serve(
      archivePath,
      zip,
      headers: <String, String>{'etag': '"${'0' * 32}"'},
    );
    final Result<InstalledBuild> result = await install();
    expect(result.failureOrNull, isA<IntegrityFailure>());
    expect(
      Directory(harness.layout.stagingDir('main', version)).existsSync(),
      isFalse,
    );
  });

  test('an etag that is not an md5 is ignored', () async {
    harness.server.serve(
      archivePath,
      zipOf(macFiles),
      headers: <String, String>{'etag': '"9b2cf535f27731c974343645a3985328-3"'},
    );
    expect((await install()).isOk, isTrue);
  });

  test('an archive without the app is refused', () async {
    publishMacBuild(
      harness.server,
      guid,
      files: <String, String>{'Readme.txt': 'nothing here'},
    );
    final Result<InstalledBuild> result = await install();
    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(Directory(buildDir()).existsSync(), isFalse);
  });

  test('a disk without room for four times the archive stops early', () async {
    publishMacBuild(harness.server, guid);
    final int size = zipOf(macFiles).length;
    harness.native.freeBytes = size * 4 - 1;
    final Result<InstalledBuild> result = await install();
    final InsufficientSpaceFailure failure =
        result.failureOrNull! as InsufficientSpaceFailure;
    expect(failure.neededBytes, size * 4);
    expect(harness.server.hits(archivePath), 1);
  });

  test('etags become md5 only when they are one', () {
    expect(
      md5FromEtag('"0123456789ABCDEF0123456789abcdef"'),
      '0123456789abcdef0123456789abcdef',
    );
    expect(md5FromEtag('"abc-3"'), isNull);
    expect(md5FromEtag(null), isNull);
    expect(md5FromEtag('"'), isNull);
    expect(md5FromEtag('""'), isNull);
    expect(md5FromEtag('W/"0123456789abcdef0123456789abcdef"'), isNull);
  });
}
