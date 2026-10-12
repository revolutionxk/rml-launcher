import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class BuildRequest {
  const BuildRequest({
    required this.installId,
    required this.version,
    required this.guid,
    this.publishedAt,
  });

  final String installId;
  final StudioVersion version;
  final String guid;
  final DateTime? publishedAt;
}

final class InstalledBuild {
  const InstalledBuild({required this.build, this.replacedDir});

  final StudioBuild build;
  final String? replacedDir;
}

abstract interface class BuildInstaller {
  Future<Result<InstalledBuild>> install(
    BuildRequest request,
    TaskControl control,
  );
}
