import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';

final class DiscoveryService {
  DiscoveryService({
    required this._library,
    required this._providers,
    required this._layout,
    required this._events,
  });

  final LibraryStore _library;
  final List<DiscoveryProvider> _providers;
  final StudioLayout _layout;
  final StudioEvents _events;

  Future<void>? _inFlight;

  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _refresh() async {
    final (
      List<DiscoveredInstall> found,
      Set<InstallSource> scanned,
      Set<String> unreadable,
    ) = await _scanAll();
    final Set<String> missing = _missingBuildPaths();
    final List<StudioEvent> pending = <StudioEvent>[];
    await _library.update((StudioLibrary library) {
      StudioLibrary next = library;
      for (final StudioInstall install in library.installs) {
        if (install.isManaged && install.builds.any(_inSet(missing))) {
          next = next.upsert(_withoutMissing(install, missing));
        }
      }
      for (final DiscoveredInstall discovered in found) {
        if (unreadable.contains(discovered.id)) {
          continue;
        }
        final StudioInstall? existing = next.byId(discovered.id);
        if (existing == null) {
          next = next.upsert(_newInstall(discovered));
          pending.add(InstallAdded(discovered.id));
          continue;
        }
        final StudioBuild? before = existing.current;
        if (before == discovered.build) {
          continue;
        }
        if (before != null && before.path != discovered.build.path) {
          pending.add(
            FoundBuildChanged(
              installId: discovered.id,
              from: before,
              to: discovered.build,
            ),
          );
        }
        next = next.upsert(existing.copyWith(current: discovered.build));
      }
      final Set<String> foundIds = found
          .map((DiscoveredInstall install) => install.id)
          .toSet();
      for (final StudioInstall install in library.installs) {
        if (install.kind != InstallKind.found ||
            !scanned.contains(install.source) ||
            foundIds.contains(install.id) ||
            unreadable.contains(install.id)) {
          continue;
        }
        final bool hidden = next.hiddenFoundIds.contains(install.id);
        next = next.remove(install.id);
        if (hidden) {
          next = next.hide(install.id);
        }
        pending.add(InstallRemoved(install.id));
      }
      return next;
    });
    pending.forEach(_events.emit);
  }

  Future<(List<DiscoveredInstall>, Set<InstallSource>, Set<String>)>
  _scanAll() async {
    final List<(DiscoveryProvider, DiscoveryScan?)> results = await Future.wait(
      _providers.map(_safeScan),
    );
    final List<DiscoveredInstall> found = <DiscoveredInstall>[];
    final Set<InstallSource> scanned = <InstallSource>{};
    final Set<String> unreadable = <String>{};
    final Set<String> ids = <String>{};
    for (final (DiscoveryProvider provider, DiscoveryScan? scan) in results) {
      if (scan == null) {
        continue;
      }
      scanned.addAll(provider.sources);
      unreadable.addAll(scan.unreadable);
      for (final DiscoveredInstall install in scan.found) {
        if (ids.add(install.id)) {
          found.add(install);
        }
      }
    }
    return (found, scanned, unreadable);
  }

  Future<(DiscoveryProvider, DiscoveryScan?)> _safeScan(
    DiscoveryProvider provider,
  ) async {
    try {
      return (provider, await provider.scan());
    } catch (error, stackTrace) {
      developer.log(
        'Studio discovery provider failed',
        name: 'rml.studio',
        error: error,
        stackTrace: stackTrace,
      );
      return (provider, null);
    }
  }

  Set<String> _missingBuildPaths() {
    if (!Directory(_layout.root).existsSync()) {
      return const <String>{};
    }
    return <String>{
      for (final StudioInstall install in _library.value.installs)
        if (install.isManaged)
          for (final StudioBuild build in install.builds)
            if (_markerLost(build)) build.path,
    };
  }

  bool _markerLost(StudioBuild build) {
    final String dir = _layout.buildDirOf(build);
    return Directory(p.dirname(dir)).existsSync() && !BuildMarker.existsIn(dir);
  }

  static bool Function(StudioBuild build) _inSet(Set<String> paths) =>
      (StudioBuild build) => paths.contains(build.path);

  static StudioInstall _withoutMissing(
    StudioInstall install,
    Set<String> missing,
  ) {
    StudioBuild? keep(StudioBuild? build) =>
        build == null || missing.contains(build.path) ? null : build;
    return install.copyWith(
      current: keep(install.current),
      previous: keep(install.previous),
      ready: keep(install.ready),
    );
  }

  static StudioInstall _newInstall(DiscoveredInstall discovered) =>
      StudioInstall(
        id: discovered.id,
        name: discovered.name,
        kind: InstallKind.found,
        source: discovered.source,
        look: InstallLook(color: _colorFor(discovered.source)),
        current: discovered.build,
      );

  static IdentityColor _colorFor(InstallSource source) => switch (source) {
    InstallSource.bloxstrap => IdentityColor.violet,
    InstallSource.vinegar => IdentityColor.purple,
    InstallSource.rml => IdentityColor.orange,
    InstallSource.roblox || InstallSource.macBundle => IdentityColor.graphite,
  };
}
