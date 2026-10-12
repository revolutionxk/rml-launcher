import 'dart:io';

import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/discovery/vinegar.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

final class LaunchService {
  LaunchService({
    required this._library,
    required this._tasks,
    required this._layout,
    required this._processes,
    required this._discovery,
    required this._updates,
    required this._hooks,
    required this._vinegar,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryStore _library;
  final TaskCenter _tasks;
  final StudioLayout _layout;
  final ProcessStarter _processes;
  final DiscoveryService _discovery;
  final UpdateService _updates;
  final StudioHooks _hooks;
  final VinegarLocator _vinegar;
  final DateTime Function() _clock;

  static const Set<TaskKind> _blocking = <TaskKind>{
    TaskKind.applyUpdate,
    TaskKind.rollBack,
    TaskKind.checkFiles,
    TaskKind.uninstall,
  };

  Future<Result<void>> launch(
    String installId, {
    String? uri,
    bool applyReadyFirst = false,
  }) async {
    if (_blocked(installId)) {
      return Result<void>.err(TaskBusyFailure(installId: installId));
    }
    await _discovery.refresh();
    StudioInstall? install = _library.value.byId(installId);
    if (install == null) {
      return const Result<void>.err(NotFoundFailure(what: 'install'));
    }
    if (applyReadyFirst &&
        install.ready != null &&
        install.policy == UpdatePolicy.followLive) {
      await _updates.applyReady(installId);
      install = _library.value.byId(installId) ?? install;
    }
    final StudioInstall target = install;
    final StudioBuild? initial = target.current;
    if (initial == null) {
      return const Result<void>.err(NotFoundFailure(what: 'Studio'));
    }
    return _tasks.run<void>(
      TaskRequest(
        kind: TaskKind.launch,
        installId: installId,
        version: initial.version.text,
        exclusive: false,
      ),
      (TaskControl control) async {
        for (final PreLaunchHook hook in _hooks.preLaunch) {
          final Result<void> prepared = await hook(target);
          if (prepared.isErr) {
            return prepared;
          }
        }
        if (_blocked(installId)) {
          return Result<void>.err(TaskBusyFailure(installId: installId));
        }
        final StudioInstall? latest = _library.value.byId(installId);
        final StudioBuild? build = latest?.current;
        if (latest == null || build == null) {
          return const Result<void>.err(NotFoundFailure(what: 'Studio'));
        }
        final Result<void> started = await _start(
          build,
          uri,
          managed: latest.isManaged,
        );
        if (started.isOk) {
          await _library.update((StudioLibrary library) {
            final StudioInstall? current = library.byId(installId);
            return current == null
                ? library
                : library.upsert(current.copyWith(lastLaunchedAt: _clock()));
          });
        }
        return started;
      },
    );
  }

  bool _blocked(String installId) =>
      _blocking.contains(_tasks.activeFor(installId)?.kind);

  Future<Result<void>> _start(
    StudioBuild build,
    String? uri, {
    required bool managed,
  }) async {
    final List<String> link = <String>[?uri];
    switch (_layout.os) {
      case HostOs.windows:
        final String launcher = _layout.launcherExecutable(build);
        final String executable = uri != null && File(launcher).existsSync()
            ? launcher
            : _layout.studioExecutable(build);
        if (!File(executable).existsSync()) {
          return const Result<void>.err(NotFoundFailure(what: 'Studio'));
        }
        return _processes.startDetached(
          executable,
          link,
          workingDirectory: build.path,
        );
      case HostOs.macos:
        if (!_bundleRunnable(build, managed: managed)) {
          return const Result<void>.err(NotFoundFailure(what: 'Studio'));
        }
        return _processes.startDetached('open', <String>[
          '-n',
          '-a',
          build.path,
          ...link,
        ]);
      case HostOs.linux:
        return switch (await _vinegar.detect()) {
          VinegarKind.binary => _processes.startDetached('vinegar', link),
          VinegarKind.flatpak => _processes.startDetached('flatpak', <String>[
            'run',
            VinegarLocator.flatpakId,
            ...link,
          ]),
          null => const Result<void>.err(NotFoundFailure(what: 'Vinegar')),
        };
    }
  }

  bool _bundleRunnable(StudioBuild build, {required bool managed}) {
    if (managed) {
      return File(_layout.studioExecutable(build)).existsSync();
    }
    final Directory binaries = Directory(_layout.payloadDir(build));
    try {
      return binaries.existsSync() && binaries.listSync().isNotEmpty;
    } on FileSystemException {
      return false;
    }
  }
}
