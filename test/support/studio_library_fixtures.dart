import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

import 'memory_json_store.dart';

StudioBuild buildAt(String path, {String version = '0.690.0.1'}) => StudioBuild(
  version: StudioVersion.parse(version),
  path: path,
  guid: 'version-${version.replaceAll('.', '')}',
  installedAt: DateTime.utc(2026, 10, 12),
);

StudioInstall managedInstall(
  String id, {
  StudioBuild? current,
  StudioBuild? previous,
  StudioBuild? ready,
  UpdatePolicy policy = UpdatePolicy.followLive,
}) => StudioInstall(
  id: id,
  name: id,
  kind: InstallKind.managed,
  source: InstallSource.rml,
  look: const InstallLook(color: IdentityColor.orange),
  policy: policy,
  current: current,
  previous: previous,
  ready: ready,
);

StudioInstall foundInstall(
  String id,
  InstallSource source, {
  StudioBuild? current,
}) => StudioInstall(
  id: id,
  name: id,
  kind: InstallKind.found,
  source: source,
  look: const InstallLook(color: IdentityColor.graphite),
  current: current,
);

Future<LibraryStore> libraryWith(
  List<StudioInstall> installs, {
  MemoryJsonStore? store,
}) async {
  final LibraryStore library = await LibraryStore.open(
    InstallRepository(store ?? MemoryJsonStore()),
  );
  await library.update(
    (StudioLibrary current) => StudioLibrary(installs: installs),
  );
  return library;
}
