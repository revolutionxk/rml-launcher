import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rml ops Ação ');
  });

  tearDown(() => dir.delete(recursive: true));

  String path(String relative) => p.join(dir.path, relative);

  test('copies a tree with its sizes', () async {
    File(path('a/b/c.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('abc');
    File(path('a/d.txt')).writeAsStringSync('de');
    int copied = 0;
    final bool done = await copyTree(
      path('a'),
      path('copy'),
      onBytes: (int bytes) => copied += bytes,
    );
    expect(done, isTrue);
    expect(File(path('copy/b/c.txt')).readAsStringSync(), 'abc');
    expect(copied, 5);
    expect(await treeSize(path('a')), 5);
  });

  test('copies links as links', () async {
    Directory(path('a/A')).createSync(recursive: true);
    Link(path('a/Current')).createSync('A');
    await copyTree(path('a'), path('copy'));
    expect(FileSystemEntity.isLinkSync(path('copy/Current')), isTrue);
    expect(Link(path('copy/Current')).targetSync(), 'A');
  }, skip: Platform.isWindows);

  test('an aborted copy stops early', () async {
    File(path('a/x.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    final AbortSignal abort = AbortSignal()..abort();
    expect(await copyTree(path('a'), path('copy'), abort: abort), isFalse);
  });

  test('deleteQuietly removes anything and ignores what is missing', () async {
    File(path('f.txt')).writeAsStringSync('f');
    Directory(path('d/e')).createSync(recursive: true);
    await deleteQuietly(path('f.txt'));
    await deleteQuietly(path('d'));
    await deleteQuietly(path('missing'));
    expect(File(path('f.txt')).existsSync(), isFalse);
    expect(Directory(path('d')).existsSync(), isFalse);
  });

  test('renameWithRetry moves folders', () async {
    Directory(path('from')).createSync();
    await renameWithRetry(Directory(path('from')), path('to'));
    expect(Directory(path('to')).existsSync(), isTrue);
  });
}
