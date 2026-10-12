import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

final class DiscoveredInstall {
  const DiscoveredInstall({
    required this.id,
    required this.source,
    required this.name,
    required this.build,
  });

  final String id;
  final InstallSource source;
  final String name;
  final StudioBuild build;
}

final class DiscoveryScan {
  const DiscoveryScan({
    this.found = const <DiscoveredInstall>[],
    this.unreadable = const <String>{},
  });

  final List<DiscoveredInstall> found;
  final Set<String> unreadable;
}

abstract interface class DiscoveryProvider {
  Set<InstallSource> get sources;

  Future<DiscoveryScan> scan();
}
