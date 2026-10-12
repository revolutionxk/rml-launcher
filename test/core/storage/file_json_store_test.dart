import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
    expect(
      File(p.join(store.directory.path, 'settings.json.tmp')).existsSync(),
      isFalse,
    );
  });

  test(
    'a stale temp file from a crash does not block the next write',
    () async {
      await store.directory.create(recursive: true);
      File(p.join(store.directory.path, 'settings.json.tmp'))
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
  });
}
