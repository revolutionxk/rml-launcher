import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final class PackageRecord {
  const PackageRecord({required this.md5, required this.files});

  final String md5;
  final Map<String, int> files;
}

final class FileRecord {
  const FileRecord(this.packages);

  static const String fileName = 'rml-files.json';

  final Map<String, PackageRecord> packages;

  static Future<FileRecord> read(String buildDir) async {
    final File file = File(p.join(buildDir, fileName));
    if (!file.existsSync()) {
      return const FileRecord(<String, PackageRecord>{});
    }
    try {
      final Object? json = jsonDecode(await file.readAsString());
      final Object? packages = json is Map<String, Object?>
          ? json['packages']
          : null;
      if (packages is! Map<String, Object?>) {
        return const FileRecord(<String, PackageRecord>{});
      }
      return FileRecord(<String, PackageRecord>{
        for (final MapEntry<String, Object?> entry in packages.entries)
          if (entry.value case {
            'md5': final String md5,
            'files': final Map<String, Object?> files,
          })
            entry.key: PackageRecord(
              md5: md5,
              files: <String, int>{
                for (final MapEntry<String, Object?> file in files.entries)
                  if (file.value case final int size) file.key: size,
              },
            ),
      });
    } on FormatException {
      return const FileRecord(<String, PackageRecord>{});
    }
  }

  FileRecord withPackage(String name, PackageRecord record) =>
      FileRecord(<String, PackageRecord>{...packages, name: record});

  Future<void> write(String buildDir) => File(p.join(buildDir, fileName))
      .writeAsString(
        jsonEncode(<String, Object?>{
          'schema': 1,
          'packages': <String, Object?>{
            for (final MapEntry<String, PackageRecord> entry
                in packages.entries)
              entry.key: <String, Object?>{
                'md5': entry.value.md5,
                'files': entry.value.files,
              },
          },
        }),
        flush: true,
      );
}
