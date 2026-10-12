import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

void main() {
  const FfiNativeService service = FfiNativeService();

  test('loads the native library in the app', () {
    expect(service.version, '0.1.0');
  });

  test('reads the OS reduce motion setting', () {
    expect(service.osReducesMotion, anyOf(isNull, isTrue, isFalse));
  });

  test('hashes through the native library', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml app');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/abc.bin')..writeAsStringSync('abc');
    final Result<String> result = await service.hashFile(
      HashAlgorithm.md5,
      file.path,
    );
    expect(result.valueOrNull, '900150983cd24fb0d6963f7d28e17f72');
  });

  test('maps native errors to a NativeFailure', () async {
    final Result<String> result = await service.hashFile(
      HashAlgorithm.md5,
      '/definitely/missing/rml.bin',
    );
    expect(result.failureOrNull, isA<NativeFailure>());
  });
}
