import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/version_folders.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

typedef _Root = ({String path, InstallSource source, String name});

final class WindowsDiscovery implements DiscoveryProvider {
  WindowsDiscovery({required this._environment, required this._native});

  final Map<String, String> _environment;
  final NativeService _native;

  @override
  Set<InstallSource> get sources => const <InstallSource>{
    InstallSource.roblox,
    InstallSource.bloxstrap,
  };

  @override
  Future<DiscoveryScan> scan() async {
    final List<DiscoveredInstall> found = <DiscoveredInstall>[];
    final Set<String> unreadable = <String>{};
    for (final _Root root in _roots()) {
      final String id = foundInstallId(
        root.source,
        root.path,
        ignoreCase: true,
      );
      final VersionsScan result = scanVersionsRoot(root.path, _native);
      final StudioBuild? build = result.build;
      if (build != null) {
        found.add(
          DiscoveredInstall(
            id: id,
            source: root.source,
            name: root.name,
            build: build,
          ),
        );
      } else if (result.unreadable) {
        unreadable.add(id);
      }
    }
    return DiscoveryScan(found: found, unreadable: unreadable);
  }

  List<_Root> _roots() {
    final String? local = _environment['LOCALAPPDATA'];
    final String? programs = _environment['ProgramFiles(x86)'];
    return <_Root>[
      if (local != null)
        (
          path: p.join(local, 'Roblox', 'Versions'),
          source: InstallSource.roblox,
          name: 'Roblox',
        ),
      if (programs != null)
        (
          path: p.join(programs, 'Roblox', 'Versions'),
          source: InstallSource.roblox,
          name: 'Roblox (all users)',
        ),
      if (local != null)
        (
          path: p.join(local, 'Bloxstrap', 'Versions'),
          source: InstallSource.bloxstrap,
          name: 'Bloxstrap',
        ),
    ];
  }
}
