import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/state/value_hub.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/running_studio.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

final class RunningWatcher {
  RunningWatcher({
    required this._native,
    required this._library,
    required this._os,
    required this._events,
    DateTime Function()? clock,
    this.visibleInterval = const Duration(seconds: 2),
    this.hiddenInterval = const Duration(seconds: 10),
  }) : _clock = clock ?? DateTime.now;

  final Duration visibleInterval;
  final Duration hiddenInterval;
  final NativeService _native;
  final LibraryStore _library;
  final HostOs _os;
  final StudioEvents _events;
  final DateTime Function() _clock;
  final ValueHub<List<RunningStudio>> _running = ValueHub<List<RunningStudio>>(
    const <RunningStudio>[],
  );
  Timer? _timer;
  bool _visible = true;

  static String executableFor(HostOs os) =>
      os == HostOs.macos ? 'RobloxStudio' : 'RobloxStudioBeta.exe';

  List<RunningStudio> get running => _running.value;

  Stream<List<RunningStudio>> watch() => _running.watch();

  Duration get interval => _visible ? visibleInterval : hiddenInterval;

  void start() {
    _schedule();
    poll();
  }

  void setVisible({required bool visible}) {
    if (_visible == visible) {
      return;
    }
    _visible = visible;
    if (_timer != null) {
      _schedule();
    }
  }

  List<RunningStudio> poll() => _refresh() ?? running;

  bool isRunning(String installId) =>
      _refresh()?.any(
        (RunningStudio studio) => studio.installId == installId,
      ) ??
      true;

  List<RunningStudio>? _refresh() {
    final List<NativeProcess>? found = _native
        .findProcesses(executableFor(_os))
        .valueOrNull;
    if (found == null) {
      return null;
    }
    final Map<int, RunningStudio> before = <int, RunningStudio>{
      for (final RunningStudio studio in running) studio.pid: studio,
    };
    final List<RunningStudio> next = <RunningStudio>[
      for (final NativeProcess process in found)
        RunningStudio(
          pid: process.pid,
          executable: process.path,
          startedAt: before[process.pid]?.startedAt ?? _clock(),
          installId: _installFor(process.path),
        ),
    ];
    final Set<int> alive = next
        .map((RunningStudio studio) => studio.pid)
        .toSet();
    for (final RunningStudio studio in next) {
      if (!before.containsKey(studio.pid)) {
        _events.emit(StudioStarted(studio));
      }
    }
    for (final RunningStudio studio in running) {
      if (!alive.contains(studio.pid)) {
        _events.emit(StudioExited(studio));
      }
    }
    if (!_same(running, next)) {
      _running.value = List<RunningStudio>.unmodifiable(next);
    }
    return next;
  }

  Result<void> close(int pid) => _native.closeProcess(pid);

  Result<void> forceQuit(int pid) {
    final Result<void> killed = _native.killProcess(pid);
    poll();
    return killed;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _running.close();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => poll());
  }

  String? _installFor(String path) {
    final List<StudioInstall> installs = _library.value.installs;
    if (_os == HostOs.linux) {
      return installs
          .where(
            (StudioInstall install) => install.source == InstallSource.vinegar,
          )
          .firstOrNull
          ?.id;
    }
    final String target = _normal(path);
    for (final StudioInstall install in installs) {
      for (final StudioBuild build in install.builds) {
        final String root = _normal(build.path);
        if (target == root || p.isWithin(root, target)) {
          return install.id;
        }
      }
    }
    return null;
  }

  String _normal(String path) {
    final String normal = p.normalize(path);
    return _os == HostOs.windows ? normal.toLowerCase() : normal;
  }

  static bool _same(List<RunningStudio> a, List<RunningStudio> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      if (a[index].pid != b[index].pid ||
          a[index].installId != b[index].installId) {
        return false;
      }
    }
    return true;
  }
}
