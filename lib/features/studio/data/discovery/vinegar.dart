import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/discovery/version_folders.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

enum VinegarKind { binary, flatpak }

final class VinegarLocator {
  VinegarLocator({required this._environment, required this._processes});

  static const String flatpakId = 'org.vinegarhq.Vinegar';

  final Map<String, String> _environment;
  final ProcessStarter _processes;

  Future<VinegarKind?> detect() async {
    if (_onPath('vinegar')) {
      return VinegarKind.binary;
    }
    final ProcessOutput info = await _processes.run('flatpak', <String>[
      'info',
      flatpakId,
    ]);
    return info.exitCode == 0 ? VinegarKind.flatpak : null;
  }

  String? dataDir(VinegarKind kind) {
    final String? home = _environment['HOME'];
    switch (kind) {
      case VinegarKind.flatpak:
        return home == null
            ? null
            : p.join(home, '.var', 'app', flatpakId, 'data', 'vinegar');
      case VinegarKind.binary:
        final String? xdg = _environment['XDG_DATA_HOME'];
        final String? base = xdg != null && xdg.isNotEmpty
            ? xdg
            : home == null
            ? null
            : p.join(home, '.local', 'share');
        return base == null ? null : p.join(base, 'vinegar');
    }
  }

  bool _onPath(String program) {
    final String? path = _environment['PATH'];
    if (path == null) {
      return false;
    }
    return path
        .split(Platform.isWindows ? ';' : ':')
        .where((String dir) => dir.isNotEmpty)
        .any((String dir) => File(p.join(dir, program)).existsSync());
  }
}

final class VinegarDiscovery implements DiscoveryProvider {
  VinegarDiscovery({required this._locator, required this._native});

  final VinegarLocator _locator;
  final NativeService _native;

  @override
  Set<InstallSource> get sources => const <InstallSource>{
    InstallSource.vinegar,
  };

  @override
  Future<List<DiscoveredInstall>> scan() async {
    final VinegarKind? kind = await _locator.detect();
    final String? data = kind == null ? null : _locator.dataDir(kind);
    if (data == null) {
      return const <DiscoveredInstall>[];
    }
    final File? executable = newestStudioExecutable(p.join(data, 'versions'));
    final StudioBuild? build = executable == null
        ? null
        : buildFromVersionFolder(executable, _native);
    if (build == null) {
      return const <DiscoveredInstall>[];
    }
    return <DiscoveredInstall>[
      DiscoveredInstall(
        id: foundInstallId(InstallSource.vinegar, data),
        source: InstallSource.vinegar,
        name: 'Vinegar',
        build: build,
      ),
    ];
  }
}
