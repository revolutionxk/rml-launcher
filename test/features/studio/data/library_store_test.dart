import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';

import '../../../support/memory_json_store.dart';

StudioInstall install(String id) => StudioInstall(
  id: id,
  name: id,
  kind: InstallKind.managed,
  source: InstallSource.rml,
  look: const InstallLook(color: IdentityColor.orange),
);

void main() {
  test('an empty store opens an empty library', () async {
    final LibraryStore store = await LibraryStore.open(
      InstallRepository(MemoryJsonStore()),
    );
    addTearDown(store.close);
    expect(store.value.installs, isEmpty);
  });

  test('updates are saved and published', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    final Future<StudioLibrary> published = store.changes.first;
    final Result<StudioLibrary> result = await store.update(
      (StudioLibrary library) => library.upsert(install('main')),
    );
    expect(result.valueOrNull!.ids, <String>['main']);
    expect((await published).ids, <String>['main']);
    final LibraryStore reopened = await LibraryStore.open(
      InstallRepository(json),
    );
    addTearDown(reopened.close);
    expect(reopened.value.ids, <String>['main']);
  });

  test('overlapping updates both apply in call order', () async {
    final LibraryStore store = await LibraryStore.open(
      InstallRepository(MemoryJsonStore()),
    );
    addTearDown(store.close);
    await Future.wait(<Future<Result<StudioLibrary>>>[
      store.update((StudioLibrary library) => library.upsert(install('a'))),
      store.update((StudioLibrary library) => library.upsert(install('b'))),
    ]);
    expect(store.value.ids, <String>['a', 'b']);
  });

  test('watch starts with the current library', () async {
    final LibraryStore store = await LibraryStore.open(
      InstallRepository(MemoryJsonStore()),
    );
    addTearDown(store.close);
    await store.update((StudioLibrary library) => library.upsert(install('a')));
    expect((await store.watch().first).ids, <String>['a']);
  });

  test('a corrupt installs file opens an empty library', () async {
    final Directory root = await Directory.systemTemp.createTemp('rml lib');
    addTearDown(() => root.delete(recursive: true));
    File(p.join(root.path, 'installs.json')).writeAsStringSync('{broken');
    final LibraryStore store = await LibraryStore.open(
      InstallRepository(FileJsonStore(root)),
    );
    addTearDown(store.close);
    expect(store.value.installs, isEmpty);
  });

  test('an install list that is not utf-8 is set aside and replaced', () async {
    final Directory root = await Directory.systemTemp.createTemp('rml lib');
    addTearDown(() => root.delete(recursive: true));
    const List<int> bytes = <int>[0x7b, 0xff, 0xfe, 0x7d];
    File(p.join(root.path, 'installs.json')).writeAsBytesSync(bytes);
    final LibraryStore store = await LibraryStore.open(
      InstallRepository(FileJsonStore(root)),
    );
    addTearDown(store.close);
    expect(store.loadFailure, isNull);
    expect(store.value.installs, isEmpty);
    final File aside = root.listSync().whereType<File>().singleWhere(
      (File file) => p.basename(file.path).startsWith('installs.json.corrupt-'),
    );
    expect(aside.readAsBytesSync(), bytes);
    final Result<StudioLibrary> saved = await store.update(
      (StudioLibrary library) => library.upsert(install('a')),
    );
    expect(saved.isOk, isTrue);
    expect(
      File(p.join(root.path, 'installs.json')).readAsStringSync(),
      contains('"a"'),
    );
  });

  String saved(List<StudioInstall> installs) =>
      jsonEncode(StudioLibrary(installs: installs).toJson());

  test('a read that fails for a moment is retried', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    json.documents['installs'] = saved(<StudioInstall>[install('main')]);
    json.readFailures.addAll(<AppFailure>[
      const IoFailure(path: 'installs.json'),
      const IoFailure(path: 'installs.json'),
    ]);
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    expect(json.reads, 3);
    expect(store.loadFailure, isNull);
    expect(store.value.ids, <String>['main']);
  });

  test('a library that cannot be read is empty and refuses changes', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final String before = saved(<StudioInstall>[install('main')]);
    json.documents['installs'] = before;
    json.readFailures.addAll(
      List<AppFailure>.filled(3, const IoFailure(path: 'installs.json')),
    );
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    expect(json.reads, 3);
    expect(store.loadFailure, isA<IoFailure>());
    expect(store.value.installs, isEmpty);
    final Result<StudioLibrary> refused = await store.update(
      (StudioLibrary library) => library.upsert(install('other')),
    );
    expect(refused.failureOrNull, same(store.loadFailure));
    expect(store.value.installs, isEmpty);
    expect(json.writes, 0);
    expect(json.documents['installs'], before);
  });

  test('a library from a newer launcher is read once and left alone', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final String newer = jsonEncode(<String, Object?>{
      ...jsonDecode(saved(<StudioInstall>[install('main')])) as JsonMap,
      'schema': 2,
      'workspaces': <Object?>[],
    });
    json.documents['installs'] = newer;
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    expect(json.reads, 1);
    expect(store.loadFailure, isA<ValidationFailure>());
    expect(store.value.installs, isEmpty);
    expect(
      (await store.update(
        (StudioLibrary library) => library.upsert(install('other')),
      )).isErr,
      isTrue,
    );
    expect(json.writes, 0);
    expect(json.documents['installs'], newer);
  });

  test('an update that changes nothing is not saved', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    final Result<StudioLibrary> result = await store.update(
      (StudioLibrary library) => library,
    );
    expect(result.valueOrNull, same(store.value));
    expect(json.writes, 0);
  });

  test('the saved document carries the schema', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    await store.update((StudioLibrary library) => library.upsert(install('a')));
    final JsonMap saved = (await json.read('installs')).valueOrNull!;
    expect(saved['schema'], 1);
  });
}
