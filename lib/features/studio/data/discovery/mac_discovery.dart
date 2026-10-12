import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class MacDiscovery implements DiscoveryProvider {
  MacDiscovery({
    required this._searchPaths,
    required this._native,
    required this._processes,
    required this._studioRoot,
    this._useSpotlight = true,
  });

  factory MacDiscovery.standard({
    required String home,
    required NativeService native,
    required ProcessStarter processes,
    required String studioRoot,
  }) => MacDiscovery(
    searchPaths: <String>[
      '/Applications/RobloxStudio.app',
      p.join(home, 'Applications', 'RobloxStudio.app'),
    ],
    native: native,
    processes: processes,
    studioRoot: studioRoot,
  );

  static const String bundleIdentifier = 'com.roblox.robloxstudio';
  static const String spotlightQuery =
      "kMDItemCFBundleIdentifier ==[c] 'com.roblox.RobloxStudio'";

  final List<String> _searchPaths;
  final NativeService _native;
  final ProcessStarter _processes;
  final String _studioRoot;
  final bool _useSpotlight;

  @override
  Set<InstallSource> get sources => const <InstallSource>{
    InstallSource.macBundle,
  };

  @override
  Future<DiscoveryScan> scan() async {
    final List<String> candidates = <String>[
      ..._searchPaths,
      if (_useSpotlight) ...await _spotlight(),
    ];
    final Set<String> seen = <String>{};
    final List<DiscoveredInstall> found = <DiscoveredInstall>[];
    final Set<String> unreadable = <String>{};
    for (final String candidate in candidates) {
      final String bundle = p.normalize(candidate);
      if (!seen.add(bundle) ||
          p.isWithin(_studioRoot, bundle) ||
          BuildMarker.existsIn(p.dirname(bundle))) {
        continue;
      }
      final String id = foundInstallId(InstallSource.macBundle, bundle);
      final Result<StudioBuild?> read = _read(bundle);
      if (read.isErr) {
        unreadable.add(id);
      } else if (read.valueOrNull case final StudioBuild build) {
        found.add(
          DiscoveredInstall(
            id: id,
            source: InstallSource.macBundle,
            name: 'Roblox Studio',
            build: build,
          ),
        );
      }
    }
    return DiscoveryScan(found: found, unreadable: unreadable);
  }

  Future<List<String>> _spotlight() async {
    final ProcessOutput output = await _processes.run('mdfind', <String>[
      spotlightQuery,
    ]);
    if (output.exitCode != 0) {
      throw ProcessException(
        'mdfind',
        const <String>[spotlightQuery],
        'Spotlight search failed',
        output.exitCode,
      );
    }
    return const LineSplitter()
        .convert(output.stdout)
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  Result<StudioBuild?> _read(String bundle) {
    if (!Directory(bundle).existsSync()) {
      return const Result<StudioBuild?>.ok(null);
    }
    final Result<ExecutableInfo> read = _native.executableInfo(bundle);
    final ExecutableInfo? info = read.valueOrNull;
    if (info == null) {
      return Result<StudioBuild?>.err(read.failureOrNull!);
    }
    if (info.identifier?.toLowerCase() != bundleIdentifier) {
      return const Result<StudioBuild?>.ok(null);
    }
    final String executable = info.executable ?? '';
    final File binary = File(p.join(bundle, 'Contents', 'MacOS', executable));
    final StudioVersion? version = StudioVersion.tryParse(info.version ?? '');
    if (executable.isEmpty || !binary.existsSync() || version == null) {
      return Result<StudioBuild?>.err(IoFailure(path: bundle));
    }
    return Result<StudioBuild?>.ok(
      StudioBuild(
        version: version,
        path: bundle,
        installedAt: binary.lastModifiedSync().toUtc(),
      ),
    );
  }
}
