import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:rml_native/rml_native.dart' as rml;

import 'fixture_server.dart';

final class FixturePackage {
  const FixturePackage(this.name, this.files);

  final String name;
  final Map<String, String> files;

  int get unpacked => files.values.fold(
    0,
    (int sum, String content) => sum + utf8.encode(content).length,
  );
}

const List<FixturePackage> windowsPackages = <FixturePackage>[
  FixturePackage('RobloxApp.zip', <String, String>{
    'RobloxStudioBeta.exe': 'studio',
    'RobloxStudioLauncherBeta.exe': 'launcher',
  }),
  FixturePackage('content-avatar.zip', <String, String>{
    'x.png': 'avatar',
    'faces/y.png': 'face',
  }),
  FixturePackage('ApplicationConfig.zip', <String, String>{
    'Settings.json': '{}',
  }),
  FixturePackage('Libraries.zip', <String, String>{'lib.dll': 'library'}),
];

const Map<String, String> macFiles = <String, String>{
  'RobloxStudio.app/Contents/MacOS/RobloxStudio': 'studio',
  'RobloxStudio.app/Contents/Info.plist': '<plist/>',
};

Uint8List zipOf(Map<String, String> files) {
  final Archive archive = Archive();
  files.forEach(
    (String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content)),
  );
  return ZipEncoder().encodeBytes(archive);
}

String md5Of(List<int> bytes) =>
    rml.hashBytes(rml.HashAlgorithm.md5, Uint8List.fromList(bytes));

void publishLive(
  FixtureServer server,
  String binaryTarget,
  String version,
  String guid,
) => server.serveText(
  'client-version/$binaryTarget/channel/LIVE',
  jsonEncode(<String, String>{'version': version, 'clientVersionUpload': guid}),
);

void publishWindowsBuild(
  FixtureServer server,
  String guid, {
  List<FixturePackage> packages = windowsPackages,
  Set<String> wrongMd5 = const <String>{},
}) {
  final StringBuffer manifest = StringBuffer('v0\n');
  for (final FixturePackage package in packages) {
    final Uint8List zip = zipOf(package.files);
    server.serve('setup/$guid-${package.name}', zip);
    manifest
      ..writeln(package.name)
      ..writeln(wrongMd5.contains(package.name) ? '0' * 32 : md5Of(zip))
      ..writeln(zip.length)
      ..writeln(package.unpacked);
  }
  server.serveText('setup/$guid-rbxPkgManifest.txt', manifest.toString());
}

void publishMacBuild(
  FixtureServer server,
  String guid, {
  String folder = 'mac/arm64/',
  Map<String, String>? files,
  bool etag = true,
}) {
  final Uint8List zip = zipOf(files ?? macFiles);
  server.serve(
    'setup/$folder$guid-RobloxStudioApp.zip',
    zip,
    headers: etag
        ? <String, String>{'etag': '"${md5Of(zip)}"'}
        : const <String, String>{},
  );
}

Future<void> until(bool Function() condition) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition not met in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
