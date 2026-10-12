import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/mac_discovery.dart';
import 'package:rml_launcher/features/studio/data/discovery/vinegar.dart';
import 'package:rml_launcher/features/studio/data/discovery/windows_discovery.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

import '../../../../support/fake_native_service.dart';
import '../../../../support/fake_process_starter.dart';

void main() {
  late Directory dir;
  late FakeNativeService native;
  late FakeProcessStarter processes;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rml discovery João ');
    native = FakeNativeService();
    processes = FakeProcessStarter();
  });

  tearDown(() => dir.delete(recursive: true));

  String path(String relative) =>
      p.joinAll(<String>[dir.path, ...relative.split('/')]);

  File studioExe(
    String folder, {
    String version = '0, 690, 0, 6900613',
    DateTime? at,
  }) {
    final File exe = File(path('$folder/RobloxStudioBeta.exe'))
      ..createSync(recursive: true)
      ..writeAsStringSync('exe');
    if (at != null) {
      exe.setLastModifiedSync(at);
    }
    native.executables[exe.path] = ExecutableInfo(version: version);
    return exe;
  }

  group('windows', () {
    WindowsDiscovery discovery({bool programFiles = false}) => WindowsDiscovery(
      environment: <String, String>{
        'LOCALAPPDATA': path('Local'),
        if (programFiles) 'ProgramFiles(x86)': path('Program Files (x86)'),
      },
      native: native,
    );

    test('finds the newest studio folder per root', () async {
      studioExe('Local/Roblox/Versions/version-old', at: DateTime(2026, 1, 1));
      studioExe('Local/Roblox/Versions/version-new', at: DateTime(2026, 9, 1));
      File(path('Local/Roblox/Versions/version-player/RobloxPlayerBeta.exe'))
        ..createSync(recursive: true)
        ..writeAsStringSync('player');
      studioExe('Local/Bloxstrap/Versions/version-b');
      final List<DiscoveredInstall> found = (await discovery().scan()).found;
      expect(found.map((DiscoveredInstall i) => i.source), <InstallSource>[
        InstallSource.roblox,
        InstallSource.bloxstrap,
      ]);
      final DiscoveredInstall roblox = found.first;
      expect(roblox.build.path, path('Local/Roblox/Versions/version-new'));
      expect(roblox.build.guid, 'version-new');
      expect(roblox.build.version.text, '0.690.0.6900613');
      expect(roblox.name, 'Roblox');
      expect(roblox.id, startsWith('roblox-'));
      expect((await discovery().scan()).found.first.id, roblox.id);
    });

    test('missing roots give nothing and unreadable ones are named', () async {
      expect((await discovery(programFiles: true).scan()).found, isEmpty);
      File(path('Local/Roblox/Versions/version-x/RobloxStudioBeta.exe'))
        ..createSync(recursive: true)
        ..writeAsStringSync('no version');
      final DiscoveryScan scan = await discovery().scan();
      expect(scan.found, isEmpty);
      expect(scan.unreadable, hasLength(1));
      expect(scan.unreadable.single, startsWith('roblox-'));
    });

    test('an unreadable newest folder falls back to an older one', () async {
      studioExe('Local/Roblox/Versions/version-old', at: DateTime(2026, 1, 1));
      File(path('Local/Roblox/Versions/version-new/RobloxStudioBeta.exe'))
        ..createSync(recursive: true)
        ..writeAsStringSync('locked')
        ..setLastModifiedSync(DateTime(2026, 9, 1));
      final DiscoveryScan scan = await discovery().scan();
      expect(scan.found.single.build.guid, 'version-old');
      expect(scan.unreadable, isEmpty);
    });

    test('one unreadable root leaves the other roots alone', () async {
      File(path('Local/Roblox/Versions/version-x/RobloxStudioBeta.exe'))
        ..createSync(recursive: true)
        ..writeAsStringSync('locked');
      studioExe('Local/Bloxstrap/Versions/version-b');
      final DiscoveryScan scan = await discovery().scan();
      expect(scan.found.single.source, InstallSource.bloxstrap);
      expect(scan.unreadable, hasLength(1));
    });

    test('the all-users root is a separate install', () async {
      studioExe('Local/Roblox/Versions/version-a');
      studioExe('Program Files (x86)/Roblox/Versions/version-a');
      final List<DiscoveredInstall> found = (await discovery(
        programFiles: true,
      ).scan()).found;
      expect(found, hasLength(2));
      expect(found[1].name, 'Roblox (all users)');
      expect(found[0].id, isNot(found[1].id));
    });
  });

  group('macos', () {
    String bundle(
      String relative, {
      String identifier = 'com.Roblox.RobloxStudio',
      bool executable = true,
    }) {
      final String root = path(relative);
      if (executable) {
        File(p.join(root, 'Contents', 'MacOS', 'RobloxStudio'))
          ..createSync(recursive: true)
          ..writeAsStringSync('bin');
      } else {
        Directory(p.join(root, 'Contents')).createSync(recursive: true);
      }
      native.executables[root] = ExecutableInfo(
        identifier: identifier,
        version: '0.700.1',
        executable: 'RobloxStudio',
      );
      return root;
    }

    MacDiscovery discovery(List<String> searchPaths) => MacDiscovery(
      searchPaths: searchPaths,
      native: native,
      processes: processes,
      studioRoot: path('Studio'),
    );

    test('finds studio bundles from fixed places and spotlight', () async {
      final String fixed = bundle('Applications/RobloxStudio.app');
      final String spotted = bundle('Elsewhere/Studio Beta.app');
      final String managed = bundle('Studio/main/builds/1/RobloxStudio.app');
      processes.outputs['mdfind ${MacDiscovery.spotlightQuery}'] =
          ProcessOutput(exitCode: 0, stdout: '$spotted\n$managed\n$fixed\n');
      final List<DiscoveredInstall> found = (await discovery(<String>[
        fixed,
        path('home/Applications/RobloxStudio.app'),
      ]).scan()).found;
      expect(found.map((DiscoveredInstall i) => i.build.path), <String>[
        fixed,
        spotted,
      ]);
      expect(found.first.source, InstallSource.macBundle);
      expect(found.first.build.version.text, '0.700.1');
      expect(found.first.id, startsWith('mac-'));
    });

    test('bundles next to a build marker are skipped', () async {
      final String managed = bundle('Linked/main/builds/2/RobloxStudio.app');
      File(p.join(p.dirname(managed), 'rml-build.json'))
          .writeAsStringSync('{}');
      expect((await discovery(<String>[managed]).scan()).found, isEmpty);
    });

    test('other apps and bundles without an executable are skipped', () async {
      final String handler = bundle(
        'Applications/Handler.app',
        identifier: 'com.Roblox.StudioProtocolHandler',
      );
      final String empty = bundle('Applications/Empty.app', executable: false);
      expect((await discovery(<String>[handler, empty]).scan()).found, isEmpty);
    });
  });

  group('vinegar', () {
    test('a vinegar binary on the path uses the xdg data folder', () async {
      File(path('bin/vinegar')).createSync(recursive: true);
      studioExe('data/vinegar/versions/version-v');
      final VinegarLocator locator = VinegarLocator(
        environment: <String, String>{
          'PATH': path('bin'),
          'HOME': path('home'),
          'XDG_DATA_HOME': path('data'),
        },
        processes: processes,
      );
      expect(await locator.detect(), VinegarKind.binary);
      final List<DiscoveredInstall> found = (await VinegarDiscovery(
        locator: locator,
        native: native,
      ).scan()).found;
      expect(found.single.source, InstallSource.vinegar);
      expect(found.single.build.path, path('data/vinegar/versions/version-v'));
      expect(found.single.name, 'Vinegar');
    });

    test('the flatpak is used when there is no binary', () async {
      processes.outputs['flatpak info ${VinegarLocator.flatpakId}'] =
          const ProcessOutput(exitCode: 0);
      final VinegarLocator locator = VinegarLocator(
        environment: <String, String>{'HOME': path('home')},
        processes: processes,
      );
      expect(await locator.detect(), VinegarKind.flatpak);
      expect(
        locator.dataDir(VinegarKind.flatpak),
        path('home/.var/app/org.vinegarhq.Vinegar/data/vinegar'),
      );
    });

    test('no vinegar means nothing', () async {
      final VinegarLocator locator = VinegarLocator(
        environment: <String, String>{'HOME': path('home')},
        processes: processes,
      );
      expect(await locator.detect(), isNull);
      expect(
        (await VinegarDiscovery(locator: locator, native: native).scan()).found,
        isEmpty,
      );
    });
  });
}
