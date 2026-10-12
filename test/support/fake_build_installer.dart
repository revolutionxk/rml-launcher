import 'dart:async';
import 'dart:io';

import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';

final class FakeBuildInstaller implements BuildInstaller {
  FakeBuildInstaller(this.layout);

  final StudioLayout layout;
  final List<BuildRequest> requests = <BuildRequest>[];
  AppFailure? failWith;
  Completer<void>? gate;

  @override
  Future<Result<InstalledBuild>> install(
    BuildRequest request,
    TaskControl control,
  ) async {
    requests.add(request);
    final Completer<void>? hold = gate;
    if (hold != null) {
      await Future.any(<Future<void>>[hold.future, control.abort.whenAborted]);
    }
    if (control.abort.isAborted) {
      return const Result<InstalledBuild>.err(CancelledFailure());
    }
    final AppFailure? failure = failWith;
    if (failure != null) {
      return Result<InstalledBuild>.err(failure);
    }
    final String dir = layout.buildDir(request.installId, request.version);
    String? replaced;
    if (Directory(dir).existsSync()) {
      replaced = layout.replacedDir(request.installId, request.version);
      await deleteQuietly(replaced);
      await Directory(dir).rename(replaced);
    }
    final StudioBuild build = StudioBuild(
      version: request.version,
      guid: request.guid,
      path: layout.buildPathIn(dir),
      installedAt: DateTime.utc(2026, 10, 12),
    );
    final File executable = File(layout.studioExecutable(build));
    await executable.parent.create(recursive: true);
    await executable.writeAsString('studio');
    await BuildMarker(
      version: request.version,
      guid: request.guid,
      binaryTarget: 'Fake',
      installedAt: build.installedAt,
    ).write(dir);
    return Result<InstalledBuild>.ok(
      InstalledBuild(build: build, replacedDir: replaced),
    );
  }
}
