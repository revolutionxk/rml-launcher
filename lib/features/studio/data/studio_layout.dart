import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class StudioLayout {
  const StudioLayout({required this.root, required this.os});

  factory StudioLayout.resolve({
    required AppPaths paths,
    required AppSettings settings,
    required HostOs os,
  }) {
    final String? custom = settings.studioRoot;
    return StudioLayout(
      root: custom != null && custom.isNotEmpty
          ? custom
          : p.join(paths.localDir, 'Studio'),
      os: os,
    );
  }

  static const String appBundle = 'RobloxStudio.app';

  final String root;
  final HostOs os;

  String get volume => os == HostOs.windows
      ? p.windows.rootPrefix(root).replaceAll(RegExp(r'[\\/]+$'), '')
      : root;

  String installDir(String installId) => p.join(root, installId);

  String buildsDir(String installId) => p.join(installDir(installId), 'builds');

  String buildDir(String installId, StudioVersion version) =>
      p.join(buildsDir(installId), version.text);

  String stagingDir(String installId, StudioVersion version) =>
      p.join(buildsDir(installId), '.${version.text}.staging');

  String replacedDir(String installId, StudioVersion version) =>
      p.join(buildsDir(installId), '.${version.text}.replaced');

  String downloadsDir(StudioVersion version) =>
      p.join(root, '.downloads', version.text);

  String buildPathIn(String buildDir) =>
      os == HostOs.macos ? p.join(buildDir, appBundle) : buildDir;

  String buildDirOf(StudioBuild build) =>
      os == HostOs.macos && build.path.endsWith('.app')
      ? p.dirname(build.path)
      : build.path;

  String payloadDir(StudioBuild build) =>
      os == HostOs.macos ? p.join(build.path, 'Contents', 'MacOS') : build.path;

  String payloadIn(String buildDir) => os == HostOs.macos
      ? p.join(buildDir, appBundle, 'Contents', 'MacOS')
      : buildDir;

  String studioExecutable(StudioBuild build) => os == HostOs.macos
      ? p.join(build.path, 'Contents', 'MacOS', 'RobloxStudio')
      : p.join(build.path, 'RobloxStudioBeta.exe');

  String launcherExecutable(StudioBuild build) =>
      p.join(build.path, 'RobloxStudioLauncherBeta.exe');

  bool owns(String path) => p.isWithin(root, path);
}
