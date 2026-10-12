import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

File? newestStudioExecutable(String versionsDir) {
  final Directory root = Directory(versionsDir);
  if (!root.existsSync()) {
    return null;
  }
  File? newest;
  for (final FileSystemEntity entry in root.listSync(followLinks: false)) {
    if (entry is! Directory) {
      continue;
    }
    final File exe = File(p.join(entry.path, 'RobloxStudioBeta.exe'));
    if (!exe.existsSync()) {
      continue;
    }
    if (newest == null ||
        exe.lastModifiedSync().isAfter(newest.lastModifiedSync())) {
      newest = exe;
    }
  }
  return newest;
}

StudioBuild? buildFromVersionFolder(File executable, NativeService native) {
  final String? raw = native
      .executableInfo(executable.path)
      .valueOrNull
      ?.version;
  final StudioVersion? version = raw == null
      ? null
      : StudioVersion.tryParse(raw);
  if (version == null) {
    return null;
  }
  final String folder = p.dirname(executable.path);
  final String name = p.basename(folder);
  return StudioBuild(
    version: version,
    path: folder,
    guid: name.startsWith('version-') ? name : null,
    installedAt: executable.lastModifiedSync(),
  );
}
