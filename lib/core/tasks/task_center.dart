import 'dart:async';
import 'dart:developer' as developer;

import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/state/value_hub.dart';
import 'package:rml_launcher/core/tasks/activity_repository.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';

typedef TaskJob<T> = Future<Result<T>> Function(TaskControl control);

final class TaskRequest {
  const TaskRequest({
    required this.kind,
    required this.installId,
    this.version,
    this.exclusive = true,
  });

  final TaskKind kind;
  final String installId;
  final String? version;
  final bool exclusive;
}

final class TaskControl {
  TaskControl._(this._center, this.taskId, this.abort);

  static const Duration _reportInterval = Duration(milliseconds: 100);

  final TaskCenter _center;
  final String taskId;
  final AbortSignal abort;
  DateTime? _lastReport;

  void phase(TaskPhase phase) =>
      _center._patch(taskId, (StudioTask task) => task.copyWith(phase: phase));

  void version(String version) => _center._patch(
    taskId,
    (StudioTask task) => task.copyWith(version: version),
  );

  void report(TaskProgress progress) {
    final DateTime now = _center._clock();
    final DateTime? last = _lastReport;
    if (progress.fraction < 1 &&
        last != null &&
        now.difference(last) < _reportInterval) {
      return;
    }
    _lastReport = now;
    _center._patch(
      taskId,
      (StudioTask task) => task.copyWith(
        progress: progress.fraction,
        bytesDone: progress.bytesDone,
        bytesTotal: progress.bytesTotal,
        speed: progress.speed,
        eta: progress.eta,
      ),
    );
  }
}

final class _Running {
  _Running({required this.request, required this.task, required this.rerun});

  final TaskRequest request;
  final Future<Result<Object?>> Function() rerun;
  StudioTask task;
  AbortSignal abort = AbortSignal();
  bool pausing = false;
  bool cancelled = false;
  Completer<bool>? _resume;

  Future<bool> waitForResume() => (_resume = Completer<bool>()).future;

  void release({required bool resume}) {
    pausing = false;
    _resume?.complete(resume);
    _resume = null;
  }
}

final class TaskCenter {
  TaskCenter({
    required this._history,
    List<StudioTask> recent = const <StudioTask>[],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _finished = List<StudioTask>.of(recent),
       _tasks = ValueHub<List<StudioTask>>(
         List<StudioTask>.unmodifiable(recent),
       );

  static Future<TaskCenter> open(
    ActivityRepository history, {
    DateTime Function()? clock,
  }) async =>
      TaskCenter(history: history, recent: await history.load(), clock: clock);

  final ActivityRepository _history;
  final DateTime Function() _clock;
  final List<StudioTask> _finished;
  final ValueHub<List<StudioTask>> _tasks;
  final Map<String, _Running> _running = <String, _Running>{};
  final Map<String, _Running> _retryable = <String, _Running>{};
  int _counter = 0;

  List<StudioTask> get tasks => _tasks.value;

  Stream<List<StudioTask>> watch() => _tasks.watch();

  StudioTask? activeFor(String installId) {
    for (final _Running running in _running.values) {
      if (running.request.installId == installId && running.request.exclusive) {
        return running.task;
      }
    }
    return null;
  }

  bool isBusy(String installId) => activeFor(installId) != null;

  Future<Result<T>> run<T>(
    TaskRequest request,
    TaskJob<T> job, {
    Future<void> Function()? onCancel,
  }) {
    if (request.exclusive && isBusy(request.installId)) {
      return Future<Result<T>>.value(
        Result<T>.err(TaskBusyFailure(installId: request.installId)),
      );
    }
    final DateTime now = _clock();
    final String id = '${now.microsecondsSinceEpoch}-${_counter++}';
    final _Running running = _Running(
      request: request,
      task: StudioTask(
        id: id,
        kind: request.kind,
        installId: request.installId,
        version: request.version,
        state: TaskState.running,
        startedAt: now,
      ),
      rerun: () => run<T>(request, job, onCancel: onCancel),
    );
    _running[id] = running;
    _publish();
    return _drive<T>(running, job, onCancel);
  }

  void pause(String taskId) {
    final _Running? running = _running[taskId];
    if (running == null || running.pausing || !running.task.kind.pausable) {
      return;
    }
    running.pausing = true;
    running.abort.abort();
  }

  void resume(String taskId) {
    final _Running? running = _running[taskId];
    if (running == null || running.task.state != TaskState.paused) {
      return;
    }
    running.release(resume: true);
  }

  void cancel(String taskId) {
    final _Running? running = _running[taskId];
    if (running == null) {
      return;
    }
    running.cancelled = true;
    running.abort.abort();
    running.release(resume: false);
  }

  bool canRetry(String taskId) => _retryable.containsKey(taskId);

  Future<Result<Object?>>? retry(String taskId) {
    final _Running? failed = _retryable[taskId];
    if (failed == null) {
      return null;
    }
    final TaskRequest request = failed.request;
    if (request.exclusive && isBusy(request.installId)) {
      return Future<Result<Object?>>.value(
        Result<Object?>.err(TaskBusyFailure(installId: request.installId)),
      );
    }
    _retryable.remove(taskId);
    return failed.rerun();
  }

  void forgetRetries(String installId) => _retryable.removeWhere(
    (String _, _Running failed) => failed.request.installId == installId,
  );

  Future<Result<T>> _drive<T>(
    _Running running,
    TaskJob<T> job,
    Future<void> Function()? onCancel,
  ) async {
    while (true) {
      running.abort = AbortSignal();
      _patch(
        running.task.id,
        (StudioTask task) => task.copyWith(state: TaskState.running),
      );
      final Result<T> result = await _attempt(
        job,
        TaskControl._(this, running.task.id, running.abort),
      );
      if (result.isOk) {
        await _finish(running, TaskState.done);
        return result;
      }
      if (running.pausing && !running.cancelled) {
        _patch(
          running.task.id,
          (StudioTask task) =>
              task.copyWith(state: TaskState.paused, speed: 0, eta: null),
        );
        if (await running.waitForResume()) {
          continue;
        }
      }
      if (running.cancelled) {
        await _cleanUp(onCancel);
        await _finish(running, TaskState.cancelled, const CancelledFailure());
        return Result<T>.err(const CancelledFailure());
      }
      await _finish(running, TaskState.failed, result.failureOrNull);
      return result;
    }
  }

  Future<Result<T>> _attempt<T>(TaskJob<T> job, TaskControl control) async {
    try {
      return await job(control);
    } catch (error, stackTrace) {
      return Result<T>.err(
        UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    }
  }

  Future<void> _cleanUp(Future<void> Function()? onCancel) async {
    try {
      await onCancel?.call();
    } catch (error, stackTrace) {
      developer.log(
        'Task clean-up after a cancel failed',
        name: 'rml.tasks',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _finish(
    _Running running,
    TaskState state, [
    AppFailure? failure,
  ]) async {
    _running.remove(running.task.id);
    final StudioTask finished = running.task.copyWith(
      state: state,
      failure: failure,
      failureCode: failure?.code,
      finishedAt: _clock(),
      speed: 0,
      eta: null,
    );
    if (state == TaskState.failed) {
      _retryable[finished.id] = running;
    }
    if (finished.kind.recorded) {
      _finished.insert(0, finished);
      if (_finished.length > ActivityRepository.limit) {
        _finished.removeRange(ActivityRepository.limit, _finished.length);
      }
    }
    _publish();
    if (finished.kind.recorded) {
      await _history.save(_finished);
    }
  }

  void _patch(String taskId, StudioTask Function(StudioTask task) change) {
    final _Running? running = _running[taskId];
    if (running == null) {
      return;
    }
    running.task = change(running.task);
    _publish();
  }

  void _publish() {
    final List<StudioTask> active =
        _running.values.map((_Running running) => running.task).toList()..sort(
          (StudioTask a, StudioTask b) => a.startedAt.compareTo(b.startedAt),
        );
    _tasks.value = List<StudioTask>.unmodifiable(<StudioTask>[
      ...active,
      ..._finished,
    ]);
  }
}
