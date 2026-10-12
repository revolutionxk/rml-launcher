import 'dart:io';

import 'package:archive/archive.dart';
import 'package:rml_native/rml_native.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rml native zip Ação ');
  });

  tearDown(() => dir.delete(recursive: true));

  File zipOf(Map<String, String> files) {
    final Archive archive = Archive();
    files.forEach(
      (String name, String content) =>
          archive.addFile(ArchiveFile.string(name, content)),
    );
    return File('${dir.path}/package.zip')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  }

  test('extracts files and reports them', () async {
    final File zip = zipOf(<String, String>{
      'RobloxStudioBeta.exe': 'exe',
      'content/fonts/a.ttf': 'font',
    });
    final List<(int, int)> progress = <(int, int)>[];
    final ExtractedArchive result = await extractZip(
      zip.path,
      '${dir.path}/out',
      onProgress: (int done, int total) => progress.add((done, total)),
    );
    expect(result.bytes, 7);
    expect(result.files.map((ExtractedFile file) => file.path), <String>[
      'RobloxStudioBeta.exe',
      'content/fonts/a.ttf',
    ]);
    expect(result.files.last.size, 4);
    expect(
      File('${dir.path}/out/content/fonts/a.ttf').readAsStringSync(),
      'font',
    );
    expect(progress.last, (7, 7));
  });

  test('a file that is not a zip fails with an io error', () async {
    final File text = File('${dir.path}/notes.zip')..writeAsStringSync('no');
    await expectLater(
      extractZip(text.path, '${dir.path}/out'),
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
