import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

StudioBuild build(String version, String path) => StudioBuild(
  version: StudioVersion.parse(version),
  path: path,
  installedAt: DateTime.utc(2026, 10, 12),
  guid: 'version-$version',
);

StudioInstall install(
  String id, {
  InstallKind kind = InstallKind.managed,
  DateTime? launched,
}) => StudioInstall(
  id: id,
  name: id,
  kind: kind,
  source: kind == InstallKind.managed
      ? InstallSource.rml
      : InstallSource.bloxstrap,
  look: const InstallLook(color: IdentityColor.orange, monogram: 'M'),
  current: build('0.690.0.1', '/studio/$id'),
  lastLaunchedAt: launched,
);

void main() {
  test('round-trips through json', () {
    final StudioLibrary library = StudioLibrary(
      installs: <StudioInstall>[
        install('main').copyWith(
          policy: UpdatePolicy.pinned,
          previous: build('0.689.0.1', '/studio/main-old'),
          ready: build('0.691.0.1', '/studio/main-new'),
          pinnedInSidebar: true,
          lastLaunchedAt: DateTime.utc(2026, 10, 11, 9),
        ),
        install('bloxstrap-1a2b3c4d', kind: InstallKind.found),
      ],
      defaultInstallId: 'main',
      hiddenFoundIds: <String>{'bloxstrap-1a2b3c4d'},
    );
    final JsonMap json = library.toJson();
    expect(json['schema'], 1);
    final StudioLibrary restored = StudioLibrary.fromJson(json);
    expect(restored.toJson(), json);
    final StudioInstall main = restored.byId('main')!;
    expect(main.policy, UpdatePolicy.pinned);
    expect(main.ready!.version.text, '0.691.0.1');
    expect(main.look.color, IdentityColor.orange);
    expect(main.lastLaunchedAt, DateTime.utc(2026, 10, 11, 9));
  });

  test('bad and duplicate installs are skipped', () {
    final StudioLibrary library = StudioLibrary.fromJson(<String, Object?>{
      'installs': <Object?>[
        install('main').toJson(),
        <String, Object?>{'id': 'broken'},
        'not an object',
        <String, Object?>{...install('legacy').toJson(), 'kind': 'sideways'},
        <String, Object?>{...install('main').toJson(), 'name': 'Second main'},
      ],
      'hiddenFoundIds': <Object?>['x', 3],
    });
    expect(library.ids, <String>['main']);
    expect(library.byId('main')!.name, 'main');
    expect(library.hiddenFoundIds, <String>{'x'});
  });

  test('a build with a bad version is dropped but the install stays', () {
    final StudioLibrary library = StudioLibrary.fromJson(<String, Object?>{
      'installs': <Object?>[
        <String, Object?>{
          ...install('main').toJson(),
          'current': <String, Object?>{'version': 'x', 'path': '/a'},
        },
      ],
    });
    expect(library.byId('main')!.current, isNull);
  });

  test('the default install follows the documented order', () {
    final StudioInstall found = install('found', kind: InstallKind.found);
    final StudioInstall managed = install('managed');
    final StudioInstall launched = install(
      'launched',
      kind: InstallKind.found,
      launched: DateTime.utc(2026, 10, 1),
    );
    expect(StudioLibrary.empty.defaultInstall, isNull);
    expect(
      StudioLibrary(installs: <StudioInstall>[found]).defaultInstall!.id,
      'found',
    );
    expect(
      StudioLibrary(installs: <StudioInstall>[found, managed])
          .defaultInstall!
          .id,
      'managed',
    );
    expect(
      StudioLibrary(installs: <StudioInstall>[found, managed, launched])
          .defaultInstall!
          .id,
      'launched',
    );
    expect(
      StudioLibrary(
        installs: <StudioInstall>[found, managed, launched],
        defaultInstallId: 'found',
      ).defaultInstall!.id,
      'found',
    );
    expect(
      StudioLibrary(
        installs: <StudioInstall>[found, managed],
        defaultInstallId: 'found',
        hiddenFoundIds: <String>{'found'},
      ).defaultInstall!.id,
      'managed',
    );
  });

  test('upsert replaces in place and remove clears the default', () {
    final StudioLibrary library = StudioLibrary(
      installs: <StudioInstall>[install('a'), install('b')],
      defaultInstallId: 'b',
    );
    final StudioLibrary renamed = library.upsert(
      library.byId('a')!.copyWith(name: 'Alpha'),
    );
    expect(renamed.ids, <String>['a', 'b']);
    expect(renamed.byId('a')!.name, 'Alpha');
    expect(renamed.upsert(install('c')).ids, <String>['a', 'b', 'c']);
    final StudioLibrary removed = renamed.remove('b');
    expect(removed.ids, <String>['a']);
    expect(removed.defaultInstallId, isNull);
  });

  test('hide and show change only the hidden set', () {
    final StudioLibrary library = StudioLibrary(
      installs: <StudioInstall>[install('f', kind: InstallKind.found)],
    );
    final StudioLibrary hidden = library.hide('f');
    expect(hidden.visible, isEmpty);
    expect(hidden.byId('f'), isNotNull);
    expect(hidden.show('f').visible.map((StudioInstall i) => i.id), <String>[
      'f',
    ]);
  });

  test('copyWith clears a build only when null is passed', () {
    final StudioInstall withReady = install('main')
        .copyWith(ready: build('0.691.0.1', '/r'));
    expect(withReady.copyWith(name: 'Main').ready, isNotNull);
    expect(withReady.copyWith(ready: null).ready, isNull);
    expect(withReady.builds.map((StudioBuild b) => b.path), <String>[
      '/studio/main',
      '/r',
    ]);
  });
}
