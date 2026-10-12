import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rml_native/rml_native.dart';
import 'package:test/test.dart';

void main() {
  const String abcSha256 =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

  test('reports its version', () {
    expect(nativeVersion(), '0.1.0');
  });

  test('reads the os reduce motion setting without throwing', () {
    expect(osReduceMotion, returnsNormally);
    expect(osReduceMotion(), anyOf(isNull, isTrue, isFalse));
  });

  test('hashes bytes', () {
    expect(
      hashBytes(HashAlgorithm.sha256, Uint8List.fromList(utf8.encode('abc'))),
      abcSha256,
    );
    expect(
      hashBytes(HashAlgorithm.md5, Uint8List(0)),
      'd41d8cd98f00b204e9800998ecf8427e',
    );
  });

  test('hashes a file on a native thread', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml native');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/abc.bin')..writeAsStringSync('abc');
    expect(await hashFile(HashAlgorithm.sha256, file.path), abcSha256);
  });

  test('handles non-ascii paths', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml Ação ✓ ');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/mods ção.bin')
      ..writeAsStringSync('abc');
    expect(
      await hashFile(HashAlgorithm.md5, file.path),
      '900150983cd24fb0d6963f7d28e17f72',
    );
  });

  test('a missing file fails with an io error', () async {
    await expectLater(
      hashFile(HashAlgorithm.md5, '/definitely/missing/rml.bin'),
      throwsA(
        isA<NativeException>().having(
          (NativeException error) => error.code,
          'code',
          2,
        ),
      ),
    );
  });

  test('a directory fails with an io error', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml native');
    addTearDown(() => dir.delete(recursive: true));
    await expectLater(
      hashFile(HashAlgorithm.md5, dir.path),
      throwsA(
        isA<NativeException>().having(
          (NativeException error) => error.code,
          'code',
          2,
        ),
      ),
    );
  });
}
