import 'dart:io';

import 'package:rml_native/rml_native.dart';
import 'package:test/test.dart';

void main() {
  Matcher nativeError(int code) => throwsA(
    isA<NativeException>().having(
      (NativeException error) => error.code,
      'code',
      code,
    ),
  );

  test('reports free space', () {
    expect(diskFree(Directory.systemTemp.path), greaterThan(0));
  });

  test('free space of an empty path is an invalid argument', () {
    expect(() => diskFree(''), nativeError(1));
  });

  test('lists nothing for an unknown executable', () {
    expect(findProcesses('rml-definitely-not-running'), isEmpty);
  });

  test('a process id of zero is rejected', () {
    expect(() => closeProcess(0), nativeError(1));
    expect(() => killProcess(0), nativeError(1));
  });

  test('a text file has no executable info', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml exe');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/notes.exe')..writeAsStringSync('no');
    expect(() => executableInfo(file.path), nativeError(2));
  });
}
