import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('the saved document carries the schema', () async {
    final MemoryJsonStore json = MemoryJsonStore();
    final LibraryStore store = await LibraryStore.open(InstallRepository(json));
    addTearDown(store.close);
    await store.update((StudioLibrary library) => library.upsert(install('a')));
    final JsonMap saved = (await json.read('installs')).valueOrNull!;
    expect(saved['schema'], 1);
  });
}
