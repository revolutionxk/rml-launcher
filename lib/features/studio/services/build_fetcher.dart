import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class BuildFetcher {
  BuildFetcher({
    required this._tasks,
    required this._cdn,
    required this._installer,
    required this._layout,
  });

  static const UnsupportedFailure unavailable = UnsupportedFailure(
    reason: 'Studio downloads are not available on this system.',
  );

  final TaskCenter _tasks;
  final StudioCdn? _cdn;
  final BuildInstaller? _installer;
  final StudioLayout _layout;

  bool get available => _cdn != null && _installer != null;

  StudioCdn? get cdn => _cdn;

  BuildInstaller? get installer => _installer;

  Future<Result<InstalledBuild>> fetch(
    String installId, {
    required TaskKind kind,
    required Future<Result<void>> Function(InstalledBuild installed) apply,
    StudioVersion? version,
    String? guid,
  }) async {
    final StudioCdn? cdn = _cdn;
    final BuildInstaller? installer = _installer;
    if (cdn == null || installer == null) {
      return const Result<InstalledBuild>.err(unavailable);
    }
    StudioVersion? resolved = version;
    String? taskId;
    return _tasks.run<InstalledBuild>(
      TaskRequest(kind: kind, installId: installId, version: version?.text),
      (TaskControl control) async {
        taskId = control.taskId;
        control.phase(TaskPhase.resolving);
        final Result<LiveVersion> target = await _target(cdn, version, guid);
        final LiveVersion? chosen = target.valueOrNull;
        if (chosen == null) {
          return Result<InstalledBuild>.err(target.failureOrNull!);
        }
        resolved = chosen.version;
        control.version(chosen.version.text);
        final Result<InstalledBuild> installed = await installer.install(
          BuildRequest(
            installId: installId,
            version: chosen.version,
            guid: chosen.guid,
          ),
          control,
        );
        final InstalledBuild? build = installed.valueOrNull;
        if (build == null) {
          return installed;
        }
        final Result<void> applied = await apply(build);
        if (applied.failureOrNull case final AppFailure failure) {
          return Result<InstalledBuild>.err(failure);
        }
        await _dropDownloads(chosen.version, except: control.taskId);
        return installed;
      },
      onCancel: () => _dropDownloads(resolved, except: taskId),
    );
  }

  Future<Result<LiveVersion>> _target(
    StudioCdn cdn,
    StudioVersion? version,
    String? guid,
  ) async {
    if (version == null) {
      return cdn.liveVersion();
    }
    if (guid != null) {
      return Result<LiveVersion>.ok(LiveVersion(version: version, guid: guid));
    }
    final Result<String> found = await cdn.resolveGuid(version);
    return found.map(
      (String resolved) => LiveVersion(version: version, guid: resolved),
    );
  }

  Future<void> _dropDownloads(StudioVersion? version, {String? except}) async {
    if (version == null) {
      return;
    }
    final bool inUse = _tasks.tasks.any(
      (StudioTask task) =>
          task.id != except &&
          task.state.isActive &&
          task.version == version.text,
    );
    if (!inUse) {
      await deleteQuietly(_layout.downloadsDir(version));
    }
  }
}
