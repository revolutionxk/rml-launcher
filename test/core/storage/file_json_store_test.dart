import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';

void main() {
  late Directory root;
  late FileJsonStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rml store Ação ');
    store = FileJsonStore(
      Directory(p.join(root.path, 'RMLLauncher')),
      clock: () => DateTime.utc(2026, 10, 11, 12, 30),
    );
  });

  tearDown(() => root.delete(recursive: true));

  List<String> tempFiles() => store.directory.existsSync()
      ? store.directory
            .listSync()
            .map((FileSystemEntity entry) => p.basename(entry.path))
            .where((String name) => name.endsWith('.tmp'))
            .toList()
      : <String>[];

  test('a missing document reads as null', () async {
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test('writes then reads the same document', () async {
    await store.write('settings', <String, Object?>{'palette': 'stoneAndSand'});
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.valueOrNull, <String, Object?>{'palette': 'stoneAndSand'});
  });

  test('a second write replaces the first and leaves no temp file', () async {
    await store.write('settings', <String, Object?>{'a': 1});
    await store.write('settings', <String, Object?>{'a': 2});
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.valueOrNull, <String, Object?>{'a': 2});
    expect(tempFiles(), isEmpty);
  });

  test(
    'a stale temp file from a crash does not block the next write',
    () async {
      await store.directory.create(recursive: true);
      File(p.join(store.directory.path, 'settings.json.$pid.tmp'))
          .writeAsStringSync('{"half');
      await store.write('settings', <String, Object?>{'a': 3});
      final Result<JsonMap?> result = await store.read('settings');
      expect(result.valueOrNull, <String, Object?>{'a': 3});
    },
  );

  test('corrupt json reads as null and is kept aside', () async {
    await store.directory.create(recursive: true);
    File(p.join(store.directory.path, 'settings.json'))
        .writeAsStringSync('{nope');
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.valueOrNull, isNull);
    expect(
      File(
        p.join(
          store.directory.path,
          'settings.json.corrupt-2026-10-11T12-30-00.000Z',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(store.directory.path, 'settings.json')).existsSync(),
      isFalse,
    );
  });

  test('a json list instead of an object is treated as corrupt', () async {
    await store.directory.create(recursive: true);
    File(p.join(store.directory.path, 'settings.json'))
        .writeAsStringSync('[1, 2]');
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.valueOrNull, isNull);
    expect(
      File(
        p.join(
          store.directory.path,
          'settings.json.corrupt-2026-10-11T12-30-00.000Z',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(store.directory.path, 'settings.json')).existsSync(),
      isFalse,
    );
  });

  test(
    'overlapping writes to one document keep the last and leave no temp file',
    () async {
      final Future<Result<void>> first = store.write(
        'settings',
        <String, Object?>{'a': 1},
      );
      final Future<Result<void>> second = store.write(
        'settings',
        <String, Object?>{'a': 2},
      );
      await Future.wait(<Future<Result<void>>>[first, second]);
      final Result<JsonMap?> result = await store.read('settings');
      expect(result.valueOrNull, <String, Object?>{'a': 2});
      expect(tempFiles(), isEmpty);
    },
  );

  test('a corrupt file whose set-aside fails is an io failure', () async {
    await store.directory.create(recursive: true);
    File(p.join(store.directory.path, 'settings.json'))
        .writeAsStringSync('{nope');
    Directory(
      p.join(
        store.directory.path,
        'settings.json.corrupt-2026-10-11T12-30-00.000Z',
      ),
    ).createSync();
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.failureOrNull, isA<IoFailure>());
  });

  test('a failed write removes its temp file', () async {
    await store.directory.create(recursive: true);
    Directory(p.join(store.directory.path, 'settings.json')).createSync();
    final Result<void> result = await store.write('settings', <String, Object?>{
      'a': 4,
    });
    expect(result.failureOrNull, isA<IoFailure>());
    expect(tempFiles(), isEmpty);
  });

  test('a read issued after an unawaited write sees that write', () async {
    unawaited(store.write('settings', <String, Object?>{'a': 5}));
    final Result<JsonMap?> result = await store.read('settings');
    expect(result.valueOrNull, <String, Object?>{'a': 5});
  });

  test('a value that cannot be encoded is a validation failure', () async {
    final Result<void> result = await store.write('settings', <String, Object?>{
      'v': double.nan,
    });
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(tempFiles(), isEmpty);
  });

  test('the temp file name carries the process id', () async {
    await store.directory.create(recursive: true);
    Directory(p.join(store.directory.path, 'settings.json')).createSync();
    final Result<void> result = await store.write('settings', <String, Object?>{
      'a': 6,
    });
    final IoFailure failure = result.failureOrNull! as IoFailure;
    final FileSystemException cause = failure.cause! as FileSystemException;
    expect(p.basename(cause.path!), 'settings.json.$pid.tmp');
  });
}
