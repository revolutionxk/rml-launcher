import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';

void main() {
  test('reads groups of four lines', () {
    final Result<List<PackageEntry>> result = parsePackageManifest(
      'v0\nRobloxStudio.zip\nabc123\n10\n20\ncontent-avatar.zip\ndef456\n30\n40\n',
    );
    final List<PackageEntry> entries = result.valueOrNull!;
    expect(entries, hasLength(2));
    expect(entries[0].name, 'RobloxStudio.zip');
    expect(entries[0].md5, 'abc123');
    expect(entries[0].stem, 'RobloxStudio');
    expect(entries[1].packedSize, 30);
    expect(entries[1].unpackedSize, 40);
  });

  test('skips entries that are not zips and lowercases md5', () {
    final Result<List<PackageEntry>> result = parsePackageManifest(
      'v0\r\nRobloxPlayerLauncher.exe\r\nAAA\r\n1\r\n2\r\nshaders.zip\r\nABCDEF\r\n3\r\n4\r\n',
    );
    final List<PackageEntry> entries = result.valueOrNull!;
    expect(entries.map((PackageEntry entry) => entry.name), <String>[
      'shaders.zip',
    ]);
    expect(entries.single.md5, 'abcdef');
  });

  test('a short trailing group ends the list', () {
    final Result<List<PackageEntry>> result = parsePackageManifest(
      'v0\nshaders.zip\nabc\n3\n4\nssl.zip\nabc\n',
    );
    expect(result.valueOrNull, hasLength(1));
  });

  test('an unknown header or bad size is a validation failure', () {
    expect(
      parsePackageManifest('v1\nshaders.zip\nabc\n3\n4\n').failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      parsePackageManifest('v0\nshaders.zip\nabc\nthree\n4\n').failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('extraction roots follow the table and version rules', () {
    expect(extractionRoot('content-avatar', 719), 'content/avatar');
    expect(extractionRoot('Libraries', 719), '');
    expect(extractionRoot('RobloxApp', 719), '');
    expect(extractionRoot('studiocontent-models', 719), 'StudioContent/models');
    expect(extractionRoot('studiocontent-models', 600), '');
    expect(extractionRoot('ApplicationConfig', 532), 'ApplicationConfig');
    expect(extractionRoot('ApplicationConfig', 531), '');
    expect(
      extractionRoot('content-platform-fonts', 700),
      'PlatformContent/pc/fonts',
    );
    expect(
      extractionRoot('extracontent-luapackages', 700),
      'ExtraContent/LuaPackages',
    );
    expect(extractionRoot('Content-Avatar', 719), '');
  });
}
