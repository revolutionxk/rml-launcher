import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/studio_engine.dart';
import 'package:rml_launcher/features/studio/studio_providers.dart';

import '../../support/fake_native_service.dart';
import '../../support/fake_process_starter.dart';
import '../../support/fixture_server.dart';
import '../../support/memory_json_store.dart';
import '../../support/studio_fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rml engine ');
  });

  tearDown(() => dir.delete(recursive: true));

  Future<StudioEngine> engine(
    HostOs os, {
    FixtureServer? server,
    MemoryJsonStore? store,
  }) => StudioEngine.create(
    paths: AppPaths(dataDir: dir.path, localDir: dir.path),
    settings: AppSettings.defaults,
    store: store ?? MemoryJsonStore(),
    native: FakeNativeService(),
    os: os,
    environment: <String, String>{'HOME': p.join(dir.path, 'home')},
    processes: FakeProcessStarter(),
    endpoints: server == null ? null : CdnEndpoints.local(server.base),
    abi: os == HostOs.macos ? Abi.macosArm64 : Abi.windowsX64,
  );

  test('linux has no downloads but still starts', () async {
    final StudioEngine studio = await engine(HostOs.linux);
    addTearDown(studio.dispose);
    expect(studio.layout.root, p.join(dir.path, 'Studio'));
    await studio.lifecycle.start();
    final AppFailure? failure = (await studio.installs.create(
      name: 'Main',
      look: const InstallLook(color: IdentityColor.orange),
    )).failureOrNull;
    expect(failure, isA<UnsupportedFailure>());
  });

  test(
    'windows starts, checks live and keeps the library in the store',
    () async {
      final FixtureServer server = await FixtureServer.start();
      addTearDown(server.close);
      server.serveText(
        'client-version/WindowsStudio64/channel/LIVE',
        jsonEncode(<String, String>{
          'version': '0.690.0.1',
          'clientVersionUpload': 'version-live',
        }),
      );
      final MemoryJsonStore store = MemoryJsonStore();
      final StudioEngine studio = await engine(
        HostOs.windows,
        server: server,
        store: store,
      );
      addTearDown(studio.dispose);
      await studio.lifecycle.start();
      await until(
        () => server.hits('client-version/WindowsStudio64/channel/LIVE') == 1,
      );
      await studio.installs.hide('nothing');
      expect(store.documents.containsKey('installs'), isTrue);
    },
  );

  test('providers expose the engine state', () async {
    final StudioEngine studio = await engine(HostOs.linux);
    addTearDown(studio.dispose);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [studioEngineProvider.overrideWithValue(studio)],
    );
    container
      ..listen(studioLibraryProvider, (_, _) {})
      ..listen(studioTasksProvider, (_, _) {})
      ..listen(runningStudiosProvider, (_, _) {});
    final StudioLibrary library = await container.read(
      studioLibraryProvider.future,
    );
    expect(library.installs, isEmpty);
    expect(await container.read(studioTasksProvider.future), isEmpty);
    expect(await container.read(runningStudiosProvider.future), isEmpty);
  });
}
