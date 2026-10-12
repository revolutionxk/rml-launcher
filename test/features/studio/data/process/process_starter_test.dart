import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';

void main() {
  test('a run that outlives its timeout is stopped', () async {
    final Stopwatch elapsed = Stopwatch()..start();
    final ProcessOutput output = await const SystemProcessStarter(
      timeout: Duration(milliseconds: 200),
    ).run('sh', <String>['-c', 'sleep 5']);
    expect(output.exitCode, -1);
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 4)));
  }, skip: Platform.isWindows);

  test('output that is not utf-8 is still read', () async {
    final ProcessOutput output = await const SystemProcessStarter().run(
      'sh',
      <String>['-c', r"printf 'a\377b\n'"],
    );
    expect(output.exitCode, 0);
    expect(output.stdout, 'a\uFFFDb\n');
  }, skip: Platform.isWindows);

  test('a program that cannot start reports a failed run', () async {
    final ProcessOutput output = await const SystemProcessStarter().run(
      'rml-launcher-missing-program',
      const <String>[],
    );
    expect(output.exitCode, -1);
  });
}
