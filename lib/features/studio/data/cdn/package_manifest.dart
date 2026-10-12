import 'dart:convert';

import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

final class PackageEntry {
  const PackageEntry({
    required this.name,
    required this.md5,
    required this.packedSize,
    required this.unpackedSize,
  });

  final String name;
  final String md5;
  final int packedSize;
  final int unpackedSize;

  String get stem =>
      name.endsWith('.zip') ? name.substring(0, name.length - 4) : name;
}

const Map<String, String> _roots = <String, String>{
  'ApplicationConfig': 'ApplicationConfig',
  'BuiltInPlugins': 'BuiltInPlugins',
  'BuiltInStandalonePlugins': 'BuiltInStandalonePlugins',
  'content-api-docs': 'content/api_docs',
  'content-avatar': 'content/avatar',
  'content-configs': 'content/configs',
  'content-fonts': 'content/fonts',
  'content-models': 'content/models',
  'content-platform-dictionaries': 'PlatformContent/pc/dictionaries',
  'content-platform-fonts': 'PlatformContent/pc/fonts',
  'content-qt_translations': 'content/qt_translations',
  'content-sky': 'content/sky',
  'content-sounds': 'content/sounds',
  'content-studio_svg_textures': 'content/studio_svg_textures',
  'content-terrain': 'PlatformContent/pc/terrain',
  'content-textures2': 'content/textures',
  'content-textures3': 'PlatformContent/pc/textures',
  'extracontent-luapackages': 'ExtraContent/LuaPackages',
  'extracontent-models': 'ExtraContent/models',
  'extracontent-scripts': 'ExtraContent/scripts',
  'extracontent-textures': 'ExtraContent/textures',
  'extracontent-translations': 'ExtraContent/translations',
  'Plugins': 'Plugins',
  'Qml': 'Qml',
  'shaders': 'shaders',
  'ssl': 'ssl',
  'StudioFonts': 'StudioFonts',
  'studiocontent-models': 'StudioContent/models',
  'studiocontent-textures': 'StudioContent/textures',
};

const Map<String, int> _minimumMajor = <String, int>{
  'ApplicationConfig': 532,
  'studiocontent-models': 680,
  'studiocontent-textures': 680,
};

String extractionRoot(String stem, int major) {
  final int? minimum = _minimumMajor[stem];
  if (minimum != null && major < minimum) {
    return '';
  }
  return _roots[stem] ?? '';
}

Result<List<PackageEntry>> parsePackageManifest(String text) {
  final List<String> lines = const LineSplitter().convert(text);
  final String header = lines.isEmpty ? '' : lines.first.trim();
  if (header != 'v0') {
    return Result<List<PackageEntry>>.err(
      ValidationFailure(
        message: 'Unexpected package manifest version: $header',
      ),
    );
  }
  final List<PackageEntry> entries = <PackageEntry>[];
  for (int index = 1; index + 4 <= lines.length; index += 4) {
    final String name = lines[index].trim();
    if (!name.endsWith('.zip')) {
      continue;
    }
    final int? packed = int.tryParse(lines[index + 2].trim());
    final int? unpacked = int.tryParse(lines[index + 3].trim());
    if (packed == null || unpacked == null) {
      return Result<List<PackageEntry>>.err(
        ValidationFailure(
          message: 'Bad sizes for $name in the package manifest',
        ),
      );
    }
    entries.add(
      PackageEntry(
        name: name,
        md5: lines[index + 1].trim().toLowerCase(),
        packedSize: packed,
        unpackedSize: unpacked,
      ),
    );
  }
  return Result<List<PackageEntry>>.ok(entries);
}
