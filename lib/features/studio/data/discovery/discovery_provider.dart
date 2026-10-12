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

abstract interface class DiscoveryProvider {
  Set<InstallSource> get sources;

  Future<List<DiscoveredInstall>> scan();
}
