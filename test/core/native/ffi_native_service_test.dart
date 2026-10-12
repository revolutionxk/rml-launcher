import 'dart:io';

import 'package:archive/archive.dart';
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

  test('reports free space', () {
    final Result<int> free = service.diskFree(Directory.systemTemp.path);
    expect(free.valueOrNull, greaterThan(0));
  });

  test('lists no process for an unknown executable', () {
    final Result<List<NativeProcess>> found = service.findProcesses(
      'rml-definitely-not-running',
    );
    expect(found.valueOrNull, isEmpty);
  });

  test('maps an invalid process id to a NativeFailure', () {
    final Result<void> closed = service.closeProcess(0);
    expect(
      closed.failureOrNull,
      isA<NativeFailure>().having(
        (NativeFailure failure) => failure.code,
        'code',
        1,
      ),
    );
  });

  test('maps a file without a version to a NativeFailure', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml app');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/notes.exe')..writeAsStringSync('no');
    expect(
      service.executableInfo(file.path).failureOrNull,
      isA<NativeFailure>(),
    );
  });

  test('extracts a zip through the native library', () async {
    final Directory dir = await Directory.systemTemp.createTemp('rml app');
    addTearDown(() => dir.delete(recursive: true));
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('content/a.txt', 'abc'));
    final File zip = File('${dir.path}/a.zip')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    final Result<ExtractedArchive> result = await service.extractZip(
      zip.path,
      '${dir.path}/out',
    );
    expect(result.valueOrNull?.bytes, 3);
    expect(File('${dir.path}/out/content/a.txt').readAsStringSync(), 'abc');
  });
}
