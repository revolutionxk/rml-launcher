import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/mac_build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/install/windows_build_installer.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';

final class InstallService {
  InstallService({
    required this._library,
    required this._tasks,
    required this._fetcher,
    required this._staging,
    required this._layout,
    required this._running,
    required this._events,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryStore _library;
  final TaskCenter _tasks;
  final BuildFetcher _fetcher;
  final StagingArea _staging;
  final StudioLayout _layout;
  final RunningWatcher _running;
  final StudioEvents _events;
  final DateTime Function() _clock;

  Future<Result<StudioInstall>> create({
    required String name,
    required InstallLook look,
    StudioVersion? version,
  }) async {
    if (!_fetcher.available) {
      return const Result<StudioInstall>.err(BuildFetcher.unavailable);
    }
    final String id = installIdFor(name, _library.value.ids);
    await _library.update(
      (StudioLibrary library) => library.upsert(
        StudioInstall(
          id: id,
          name: name,
          kind: InstallKind.managed,
          source: InstallSource.rml,
          look: look,
          policy: version == null
              ? UpdatePolicy.followLive
              : UpdatePolicy.pinned,
        ),
      ),
    );
    _events.emit(InstallAdded(id));
    final Result<InstalledBuild> fetched = await _fetcher.fetch(
      id,
      kind: TaskKind.install,
      version: version,
      apply: (InstalledBuild installed) => _setCurrent(id, installed),
    );
    if (fetched.failureOrNull case final AppFailure failure) {
      if (failure is CancelledFailure) {
        await _forget(id);
      }
      return Result<StudioInstall>.err(failure);
    }
    return Result<StudioInstall>.ok(_library.value.byId(id)!);
  }

  Future<Result<void>> uninstall(String installId) async {
    final StudioInstall? install = _library.value.byId(installId);
    if (install == null) {
      return const Result<void>.err(NotFoundFailure(what: 'install'));
    }
    if (!install.isManaged) {
      return const Result<void>.err(
        UnsupportedFailure(
          reason: 'Only installs RML manages can be uninstalled.',
        ),
      );
    }
    if (_running.isRunning(installId)) {
      return Result<void>.err(StudioRunningFailure(installId: installId));
    }
    return _tasks.run<void>(
      TaskRequest(kind: TaskKind.uninstall, installId: installId),
      (TaskControl control) async {
        final String dir = _layout.installDir(installId);
        if (!_layout.owns(dir)) {
          return Result<void>.err(
            ValidationFailure(
              message: 'Install id $installId is not a folder name',
            ),
          );
        }
        try {
          if (Directory(dir).existsSync()) {
            await Directory(dir).delete(recursive: true);
          }
        } on FileSystemException catch (error, stackTrace) {
          return Result<void>.err(
            IoFailure(path: dir, cause: error, stackTrace: stackTrace),
          );
        }
        await _library.update(
          (StudioLibrary library) => library.remove(installId),
        );
        _events.emit(InstallRemoved(installId));
        return const Result<void>.ok(null);
      },
    );
  }

  Future<Result<StudioInstall>> duplicate(String installId, String name) async {
    final StudioInstall? source = _library.value.byId(installId);
    final StudioBuild? build = source?.current;
    if (source == null) {
      return const Result<StudioInstall>.err(NotFoundFailure(what: 'install'));
    }
    if (build == null) {
      return const Result<StudioInstall>.err(
        NotFoundFailure(what: 'Studio build'),
      );
    }
    if (_layout.os == HostOs.linux) {
      return const Result<StudioInstall>.err(BuildFetcher.unavailable);
    }
    final String id = installIdFor(name, _library.value.ids);
    await _library.update(
      (StudioLibrary library) => library.upsert(
        StudioInstall(
          id: id,
          name: name,
          kind: InstallKind.managed,
          source: InstallSource.rml,
          look: source.look,
          policy: UpdatePolicy.pinned,
        ),
      ),
    );
    _events.emit(InstallAdded(id));
    final Result<StudioInstall> result = await _tasks.run<StudioInstall>(
      TaskRequest(
        kind: TaskKind.duplicate,
        installId: id,
        version: build.version.text,
      ),
      (TaskControl control) => _copyBuild(id, build, control),
    );
    if (result.isErr) {
      await _forget(id);
    }
    return result;
  }

  Future<Result<void>> rename(String installId, String name) =>
      _edit(installId, (StudioInstall install) => install.copyWith(name: name));

  Future<Result<void>> setLook(String installId, InstallLook look) =>
      _edit(installId, (StudioInstall install) => install.copyWith(look: look));

  Future<Result<void>> setPinned(String installId, {required bool pinned}) =>
      _edit(
        installId,
        (StudioInstall install) => install.copyWith(pinnedInSidebar: pinned),
      );

  Future<Result<void>> setDefault(String? installId) async {
    if (installId != null && _library.value.byId(installId) == null) {
      return const Result<void>.err(NotFoundFailure(what: 'install'));
    }
    final Result<StudioLibrary> saved = await _library.update(
      (StudioLibrary library) => library.withDefault(installId),
    );
    return saved.map((_) {});
  }

  Future<Result<void>> hide(String installId) async {
    final Result<StudioLibrary> saved = await _library.update(
      (StudioLibrary library) => library.hide(installId),
    );
    return saved.map((_) {});
  }

  Future<Result<void>> show(String installId) async {
    final Result<StudioLibrary> saved = await _library.update(
      (StudioLibrary library) => library.show(installId),
    );
    return saved.map((_) {});
  }

  Future<Result<void>> _edit(
    String installId,
    StudioInstall Function(StudioInstall install) change,
  ) async {
    if (_library.value.byId(installId) == null) {
      return const Result<void>.err(NotFoundFailure(what: 'install'));
    }
    final Result<StudioLibrary> saved = await _library.update((
      StudioLibrary library,
    ) {
      final StudioInstall? install = library.byId(installId);
      return install == null ? library : library.upsert(change(install));
    });
    return saved.map((_) {});
  }

  Future<Result<void>> _setCurrent(
    String installId,
    InstalledBuild installed,
  ) async {
    final Result<StudioLibrary> saved = await _library.update((
      StudioLibrary library,
    ) {
      final StudioInstall? install = library.byId(installId);
      return install == null
          ? library
          : library.upsert(install.copyWith(current: installed.build));
    });
    final String? replaced = installed.replacedDir;
    if (replaced != null) {
      await deleteQuietly(replaced);
    }
    _events.emit(
      BuildInstalled(installId: installId, version: installed.build.version),
    );
    return saved.map((_) {});
  }

  Future<Result<StudioInstall>> _copyBuild(
    String installId,
    StudioBuild build,
    TaskControl control,
  ) async {
    final Result<String> prepared = await _staging.prepare(
      installId,
      build.version,
    );
    final String? staging = prepared.valueOrNull;
    if (staging == null) {
      return Result<StudioInstall>.err(prepared.failureOrNull!);
    }
    final String target = _layout.os == HostOs.macos
        ? p.join(staging, StudioLayout.appBundle)
        : staging;
    try {
      final int total = await treeSize(build.path);
      int copied = 0;
      final bool finished = await copyTree(
        build.path,
        target,
        abort: control.abort,
        onBytes: (int bytes) {
          copied += bytes;
          control.report(
            TaskProgress(
              fraction: total == 0 ? 1 : copied / total,
              bytesDone: copied,
              bytesTotal: total,
            ),
          );
        },
      );
      if (!finished) {
        await _staging.discard(staging);
        return const Result<StudioInstall>.err(CancelledFailure());
      }
    } on FileSystemException catch (error, stackTrace) {
      await _staging.discard(staging);
      return Result<StudioInstall>.err(
        IoFailure(path: build.path, cause: error, stackTrace: stackTrace),
      );
    }
    final Result<InstalledBuild> committed = await _staging.commit(
      installId: installId,
      staging: staging,
      marker: BuildMarker(
        version: build.version,
        guid: build.guid,
        binaryTarget: _layout.os == HostOs.macos
            ? MacBuildInstaller.binaryTarget
            : WindowsBuildInstaller.binaryTarget,
        installedAt: _clock(),
        publishedAt: build.publishedAt,
      ),
    );
    final InstalledBuild? installed = committed.valueOrNull;
    if (installed == null) {
      await _staging.discard(staging);
      return Result<StudioInstall>.err(committed.failureOrNull!);
    }
    final Result<void> applied = await _setCurrent(installId, installed);
    return applied.map((_) => _library.value.byId(installId)!);
  }

  Future<void> _forget(String installId) async {
    final String dir = _layout.installDir(installId);
    if (_layout.owns(dir)) {
      await deleteQuietly(dir);
    }
    await _library.update((StudioLibrary library) => library.remove(installId));
    _events.emit(InstallRemoved(installId));
  }
}
