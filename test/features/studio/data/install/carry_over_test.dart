import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/install/carry_over.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rml carry ');
  });

  tearDown(() => dir.delete(recursive: true));

  test('moves folders and files and replaces what is there', () async {
    final String from = p.join(dir.path, 'old');
    final String to = p.join(dir.path, 'new');
    File(p.join(from, 'ClientSettings', 'ClientAppSettings.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"a":1}');
    File(p.join(from, 'RobloxModLoader', 'mods', 'x', 'mod.toml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    File(p.join(to, 'ClientSettings', 'stale.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    final Result<void> result = await moveCarryOver(
      <String>['ClientSettings', 'RobloxModLoader/mods', 'Missing'],
      from: from,
      to: to,
    );
    expect(result.isOk, isTrue);
    expect(
      File(p.join(to, 'ClientSettings', 'ClientAppSettings.json'))
          .readAsStringSync(),
      '{"a":1}',
    );
    expect(
      File(p.join(to, 'ClientSettings', 'stale.json')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(to, 'RobloxModLoader', 'mods', 'x', 'mod.toml')).existsSync(),
      isTrue,
    );
    expect(Directory(p.join(from, 'ClientSettings')).existsSync(), isFalse);
  });

  test('a failed second move puts the first back', () async {
    final String from = p.join(dir.path, 'old');
    final String to = p.join(dir.path, 'new');
    File(p.join(from, 'A', 'a.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('a');
    File(p.join(from, 'deep', 'B', 'b.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('b');
    File(p.join(to, 'deep')).createSync(recursive: true);
    final Result<void> result = await moveCarryOver(
      <String>['A', 'deep/B'],
      from: from,
      to: to,
    );
    expect(result.isErr, isTrue);
    expect(File(p.join(from, 'A', 'a.txt')).existsSync(), isTrue);
    expect(File(p.join(from, 'deep', 'B', 'b.txt')).existsSync(), isTrue);
    expect(Directory(p.join(to, 'A')).existsSync(), isFalse);
  });

  test('the same source and target is refused', () async {
    final String same = p.join(dir.path, 'same');
    File(p.join(same, 'A', 'a.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('a');
    final Result<void> result = await moveCarryOver(
      <String>['A'],
      from: same,
      to: same,
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(File(p.join(same, 'A', 'a.txt')).existsSync(), isTrue);
  });
}
