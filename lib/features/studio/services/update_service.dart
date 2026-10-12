import 'dart:async';

import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/install/build_files.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/carry_over.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';

final class UpdateService {
  UpdateService({
    required this._library,
    required this._tasks,
    required this._fetcher,
    required this._layout,
    required this._running,
    required this._hooks,
    required this._events,
    DateTime Function()? clock,
    this.focusInterval = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now;

  final Duration focusInterval;
  final LibraryStore _library;
  final TaskCenter _tasks;
  final BuildFetcher _fetcher;
  final StudioLayout _layout;
  final RunningWatcher _running;
  final StudioHooks _hooks;
  final StudioEvents _events;
  final DateTime Function() _clock;
  DateTime? _lastCheck;

  DateTime? get lastCheck => _lastCheck;

  Future<Result<void>> checkForUpdates() async {
    final StudioCdn? cdn = _fetcher.cdn;
    if (cdn == null || !_fetcher.available) {
      return const Result<void>.ok(null);
    }
    _lastCheck = _clock();
    final Result<LiveVersion> live = await cdn.liveVersion();
    final LiveVersion? latest = live.valueOrNull;
    if (latest == null) {
      return Result<void>.err(live.failureOrNull!);
    }
    final List<StudioInstall> due = _library.value.installs
        .where((StudioInstall install) => _wantsUpdate(install, latest.version))
        .toList();
    final List<Result<void>> results = await Future.wait(
      due.map((StudioInstall install) => _prepare(install, latest)),
    );
    for (final Result<void> result in results) {
      final AppFailure? failure = result.failureOrNull;
      if (failure != null && failure is! TaskBusyFailure) {
        return Result<void>.err(failure);
      }
    }
    return const Result<void>.ok(null);
  }

  Future<Result<void>> checkIfDue() {
    final DateTime? last = _lastCheck;
    if (last != null && _clock().difference(last) < focusInterval) {
      return Future<Result<void>>.value(const Result<void>.ok(null));
    }
    return checkForUpdates();
  }

  Future<UpdateReview> review(String installId) async {
    final StudioInstall? install = _library.value.byId(installId);
    final StudioBuild? ready = install?.ready;
    if (install == null || ready == null) {
      return const UpdateReview();
    }
    return _hooks.updateGate(install, ready.version);
  }

  Future<Result<void>> applyReady(String installId) => _tasks.run<void>(
    TaskRequest(kind: TaskKind.applyUpdate, installId: installId),
    (TaskControl control) async {
      if (_running.isRunning(installId)) {
        return Result<void>.err(StudioRunningFailure(installId: installId));
      }
      final StudioInstall? install = _library.value.byId(installId);
      if (install == null) {
        return const Result<void>.err(NotFoundFailure(what: 'install'));
      }
      final StudioBuild? current = install.current;
      final StudioBuild? ready = install.ready;
      if (current == null || ready == null) {
        return Result<void>.err(
          ValidationFailure(message: 'No update is ready for ${install.name}.'),
        );
      }
      control.version(ready.version.text);
      final UpdateReview verdict = await _hooks.updateGate(
        install,
        ready.version,
      );
      if (verdict.blocked) {
        return Result<void>.err(
          UpdateBlockedFailure(blockers: verdict.blockers),
        );
      }
      if (_running.isRunning(installId)) {
        return Result<void>.err(StudioRunningFailure(installId: installId));
      }
      final String from = _layout.payloadDir(current);
      final String to = _layout.payloadDir(ready);
      final Result<List<String>> moved = await moveCarryOver(
        _hooks.carryOver,
        from: from,
        to: to,
      );
      final List<String>? done = moved.valueOrNull;
      if (done == null) {
        return Result<void>.err(moved.failureOrNull!);
      }
      final Result<void> saved = await _swap(
        install,
        (StudioInstall latest) =>
            latest.copyWith(previous: current, current: ready, ready: null),
      );
      if (saved.failureOrNull case final AppFailure failure) {
        if (failure is ValidationFailure) {
          return Result<void>.err(await _undo(done, from, to, failure));
        }
        return Result<void>.err(failure);
      }
      final StudioBuild? dropped = install.previous;
      if (dropped != null) {
        await _dropUnused(dropped);
      }
      _events.emit(
        UpdateApplied(
          installId: installId,
          from: current.version,
          to: ready.version,
        ),
      );
      return const Result<void>.ok(null);
    },
  );

  Future<Result<void>> rollBack(String installId) => _tasks.run<void>(
    TaskRequest(kind: TaskKind.rollBack, installId: installId),
    (TaskControl control) async {
      if (_running.isRunning(installId)) {
        return Result<void>.err(StudioRunningFailure(installId: installId));
      }
      final StudioInstall? install = _library.value.byId(installId);
      if (install == null) {
        return const Result<void>.err(NotFoundFailure(what: 'install'));
      }
      final StudioBuild? current = install.current;
      final StudioBuild? previous = install.previous;
      if (current == null || previous == null) {
        return Result<void>.err(
          ValidationFailure(
            message: '${install.name} has no previous build to roll back to.',
          ),
        );
      }
      control.version(previous.version.text);
      final String from = _layout.payloadDir(current);
      final String to = _layout.payloadDir(previous);
      final Result<List<String>> moved = await moveCarryOver(
        _hooks.carryOver,
        from: from,
        to: to,
      );
      final List<String>? done = moved.valueOrNull;
      if (done == null) {
        return Result<void>.err(moved.failureOrNull!);
      }
      final Result<void> saved = await _swap(
        install,
        (StudioInstall latest) => latest.copyWith(
          current: previous,
          previous: current,
          policy: UpdatePolicy.pinned,
        ),
      );
      if (saved.failureOrNull case final AppFailure failure) {
        if (failure is ValidationFailure) {
          return Result<void>.err(await _undo(done, from, to, failure));
        }
        return Result<void>.err(failure);
      }
      _events.emit(
        RolledBack(
          installId: installId,
          from: current.version,
          to: previous.version,
        ),
      );
      return const Result<void>.ok(null);
    },
  );

  Future<AppFailure> _undo(
    List<String> moved,
    String from,
    String to,
    AppFailure cause,
  ) async {
    final Result<void> undone = await undoCarryOver(moved, from: from, to: to);
    return undone.failureOrNull ?? cause;
  }

  Future<Result<void>> setPolicy(String installId, UpdatePolicy policy) async {
    if (_library.value.byId(installId) == null) {
      return const Result<void>.err(NotFoundFailure(what: 'install'));
    }
    final Result<StudioLibrary> saved = await _change(
      installId,
      (StudioInstall install) => install.copyWith(policy: policy),
    );
    if (saved.failureOrNull case final AppFailure failure) {
      return Result<void>.err(failure);
    }
    if (policy == UpdatePolicy.followLive) {
      unawaited(checkForUpdates());
    }
    return const Result<void>.ok(null);
  }

  bool _wantsUpdate(StudioInstall install, StudioVersion live) {
    final StudioBuild? current = install.current;
    if (!install.isManaged ||
        install.policy != UpdatePolicy.followLive ||
        current == null ||
        _tasks.isBusy(install.id)) {
      return false;
    }
    final StudioBuild? ready = install.ready;
    final StudioVersion newest =
        ready != null && ready.version > current.version
        ? ready.version
        : current.version;
    return live > newest;
  }

  Future<Result<void>> _prepare(
    StudioInstall install,
    LiveVersion latest,
  ) async {
    final StudioBuild? previous = install.previous;
    if (previous != null && previous.version == latest.version) {
      return _promote(install, previous);
    }
    final Result<InstalledBuild> fetched = await _fetcher.fetch(
      install.id,
      kind: TaskKind.update,
      version: latest.version,
      guid: latest.guid,
      apply: (InstalledBuild installed) => _setReady(install.id, installed),
    );
    return fetched.map((_) {});
  }

  Future<Result<void>> _promote(
    StudioInstall install,
    StudioBuild previous,
  ) async {
    if (_tasks.isBusy(install.id) ||
        !BuildMarker.existsIn(_layout.buildDirOf(previous))) {
      return const Result<void>.ok(null);
    }
    final Result<void> saved = await _swap(
      install,
      (StudioInstall latest) =>
          latest.copyWith(ready: previous, previous: null),
    );
    if (saved.isErr) {
      return saved;
    }
    final StudioBuild? old = install.ready;
    if (old != null) {
      await _dropUnused(old);
    }
    _events.emit(UpdateReady(installId: install.id, version: previous.version));
    return const Result<void>.ok(null);
  }

  Future<Result<void>> _setReady(
    String installId,
    InstalledBuild installed,
  ) async {
    StudioBuild? replaced;
    final Result<StudioLibrary> saved = await _change(installId, (
      StudioInstall install,
    ) {
      replaced = install.ready;
      return install.copyWith(ready: installed.build);
    });
    if (saved.isErr) {
      return saved.map((_) {});
    }
    final StudioBuild? old = replaced;
    if (old != null) {
      await _dropUnused(old);
    }
    final String? replacedDir = installed.replacedDir;
    if (replacedDir != null) {
      await deleteQuietly(replacedDir);
    }
    _events.emit(
      UpdateReady(installId: installId, version: installed.build.version),
    );
    return saved.map((_) {});
  }

  Future<Result<void>> _swap(
    StudioInstall expected,
    StudioInstall Function(StudioInstall latest) change,
  ) async {
    bool stale = false;
    final Result<StudioLibrary> saved = await _library.update((
      StudioLibrary library,
    ) {
      final StudioInstall? latest = library.byId(expected.id);
      if (latest == null ||
          latest.current != expected.current ||
          latest.ready != expected.ready ||
          latest.previous != expected.previous) {
        stale = true;
        return library;
      }
      return library.upsert(change(latest));
    });
    if (stale) {
      return Result<void>.err(
        ValidationFailure(
          message: '${expected.name} changed while updating; try again.',
        ),
      );
    }
    return saved.map((_) {});
  }

  Future<Result<StudioLibrary>> _change(
    String installId,
    StudioInstall Function(StudioInstall install) change,
  ) => _library.update((StudioLibrary library) {
    final StudioInstall? install = library.byId(installId);
    return install == null ? library : library.upsert(change(install));
  });

  Future<void> _dropUnused(StudioBuild build) async {
    final bool used = _library.value.installs.any(
      (StudioInstall install) =>
          install.builds.any((StudioBuild other) => other.path == build.path),
    );
    if (!used) {
      await deleteManagedBuild(_layout, build);
    }
  }
}
