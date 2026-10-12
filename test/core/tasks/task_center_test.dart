import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/core/tasks/activity_repository.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';

import '../../support/memory_json_store.dart';

void main() {
  late MemoryJsonStore store;
  late TaskCenter center;

  setUp(() async {
    store = MemoryJsonStore();
    center = await TaskCenter.open(ActivityRepository(store));
  });

  TaskRequest install(String id) =>
      TaskRequest(kind: TaskKind.install, installId: id, version: '0.690');

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a finished task is recorded in the history', () async {
    final Result<int> result = await center.run<int>(install('main'), (
      TaskControl control,
    ) async {
      control
        ..phase(TaskPhase.downloading)
        ..report(const TaskProgress(fraction: 1, bytesDone: 5, bytesTotal: 5));
      return const Result<int>.ok(3);
    });
    expect(result.valueOrNull, 3);
    final StudioTask task = center.tasks.single;
    expect(task.state, TaskState.done);
    expect(task.progress, 1);
    expect(task.finishedAt, isNotNull);
    final JsonMap saved = (await store.read('activity')).valueOrNull!;
    expect((saved['tasks']! as List<Object?>), hasLength(1));
  });

  test('a failure keeps its code', () async {
    await center.run<void>(
      install('main'),
      (TaskControl control) async =>
          const Result<void>.err(NetworkFailure(statusCode: 503)),
    );
    expect(center.tasks.single.state, TaskState.failed);
    expect(center.tasks.single.failureCode, 'network');
    expect(center.tasks.single.failure, isA<NetworkFailure>());
  });

  test('a job that throws fails with an unknown failure', () async {
    final Result<void> result = await center.run<void>(
      install('main'),
      (TaskControl control) => throw StateError('boom'),
    );
    expect(result.failureOrNull, isA<UnknownFailure>());
  });

  test('one exclusive task per install, several installs at once', () async {
    final Completer<void> gate = Completer<void>();
    final Future<Result<void>> first = center.run<void>(install('main'), (
      TaskControl control,
    ) async {
      await gate.future;
      return const Result<void>.ok(null);
    });
    final Result<void> busy = await center.run<void>(
      install('main'),
      (TaskControl control) async => const Result<void>.ok(null),
    );
    expect(busy.failureOrNull, isA<TaskBusyFailure>());
    expect(center.isBusy('main'), isTrue);
    final Result<void> other = await center.run<void>(
      install('legacy'),
      (TaskControl control) async => const Result<void>.ok(null),
    );
    expect(other.isOk, isTrue);
    final Result<void> launch = await center.run<void>(
      const TaskRequest(
        kind: TaskKind.launch,
        installId: 'main',
        exclusive: false,
      ),
      (TaskControl control) async => const Result<void>.ok(null),
    );
    expect(launch.isOk, isTrue);
    gate.complete();
    await first;
    expect(center.isBusy('main'), isFalse);
  });

  test('pause aborts the job and resume runs it again', () async {
    int runs = 0;
    final Future<Result<String>> running = center.run<String>(install('main'), (
      TaskControl control,
    ) async {
      runs++;
      if (runs == 1) {
        await control.abort.whenAborted;
        return const Result<String>.err(CancelledFailure());
      }
      return const Result<String>.ok('done');
    });
    await settle();
    final String id = center.tasks.single.id;
    center.pause(id);
    await settle();
    expect(center.tasks.single.state, TaskState.paused);
    center.resume(id);
    expect((await running).valueOrNull, 'done');
    expect(runs, 2);
    expect(center.tasks.single.state, TaskState.done);
  });

  test('cancel aborts, cleans up and records the cancellation', () async {
    int cleanups = 0;
    final Future<Result<void>> running = center.run<void>(install('main'), (
      TaskControl control,
    ) async {
      await control.abort.whenAborted;
      return const Result<void>.err(CancelledFailure());
    }, onCancel: () async => cleanups++);
    await settle();
    center.cancel(center.tasks.single.id);
    expect((await running).failureOrNull, isA<CancelledFailure>());
    expect(cleanups, 1);
    expect(center.tasks.single.state, TaskState.cancelled);
  });

  test('a paused task can be cancelled', () async {
    final Future<Result<void>> running = center.run<void>(install('main'), (
      TaskControl control,
    ) async {
      await control.abort.whenAborted;
      return const Result<void>.err(CancelledFailure());
    });
    await settle();
    final String id = center.tasks.single.id;
    center.pause(id);
    await settle();
    center.cancel(id);
    expect((await running).failureOrNull, isA<CancelledFailure>());
    expect(center.tasks.single.state, TaskState.cancelled);
  });

  test('a launch task is neither pausable nor recorded', () async {
    await center.run<void>(
      const TaskRequest(
        kind: TaskKind.launch,
        installId: 'main',
        exclusive: false,
      ),
      (TaskControl control) async => const Result<void>.ok(null),
    );
    expect(center.tasks, isEmpty);
    expect(TaskKind.launch.pausable, isFalse);
  });

  test('a failed task can be retried', () async {
    int runs = 0;
    await center.run<void>(install('main'), (TaskControl control) async {
      runs++;
      return runs == 1
          ? const Result<void>.err(NetworkFailure())
          : const Result<void>.ok(null);
    });
    final String failed = center.tasks.single.id;
    final Result<Object?> retried = await center.retry(failed)!;
    expect(retried.isOk, isTrue);
    expect(runs, 2);
    expect(center.retry(failed), isNull);
  });

  test('history keeps the last twenty and survives a restart', () async {
    for (int index = 0; index < 25; index++) {
      await center.run<void>(
        install('i$index'),
        (TaskControl control) async => const Result<void>.ok(null),
      );
    }
    expect(center.tasks, hasLength(20));
    expect(center.tasks.first.installId, 'i24');
    final TaskCenter reopened = await TaskCenter.open(
      ActivityRepository(store),
    );
    expect(reopened.tasks, hasLength(20));
    expect(reopened.tasks.first.installId, 'i24');
    expect(reopened.tasks.first.state, TaskState.done);
  });

  test('watch publishes progress', () async {
    final List<double> seen = <double>[];
    final StreamSubscription<List<StudioTask>> subscription = center
        .watch()
        .listen((List<StudioTask> tasks) {
          if (tasks.isNotEmpty) {
            seen.add(tasks.first.progress);
          }
        });
    addTearDown(subscription.cancel);
    await center.run<void>(install('main'), (TaskControl control) async {
      control.report(const TaskProgress(fraction: 1));
      return const Result<void>.ok(null);
    });
    await settle();
    expect(seen, contains(1.0));
  });
}
