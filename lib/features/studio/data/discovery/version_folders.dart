import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

typedef VersionsScan = ({StudioBuild? build, bool unreadable});

VersionsScan scanVersionsRoot(String versionsDir, NativeService native) {
  try {
    final Directory root = Directory(versionsDir);
    if (!root.existsSync()) {
      return (build: null, unreadable: false);
    }
    final List<File> executables = <File>[
      for (final FileSystemEntity entry in root.listSync(followLinks: false))
        if (entry is Directory)
          if (File(p.join(entry.path, 'RobloxStudioBeta.exe'))
              case final File exe when exe.existsSync())
            exe,
    ];
    if (executables.isEmpty) {
      return (build: null, unreadable: false);
    }
    final Map<File, DateTime> modified = <File, DateTime>{
      for (final File exe in executables) exe: exe.lastModifiedSync(),
    };
    executables.sort((File a, File b) => modified[b]!.compareTo(modified[a]!));
    for (final File exe in executables) {
      final StudioBuild? build = buildFromVersionFolder(exe, native);
      if (build != null) {
        return (build: build, unreadable: false);
      }
    }
    return (build: null, unreadable: true);
  } on FileSystemException {
    return (build: null, unreadable: true);
  }
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
