import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

void main() {
  final StudioVersion version = StudioVersion.parse('0.690.0.6900613');

  StudioBuild buildAt(String path) => StudioBuild(
    version: version,
    path: path,
    installedAt: DateTime.utc(2026, 10, 12),
  );

  test('the root defaults to the local folder and can be moved', () {
    const AppPaths paths = AppPaths(dataDir: '/data', localDir: '/local');
    expect(
      StudioLayout.resolve(
        paths: paths,
        settings: AppSettings.defaults,
        os: HostOs.linux,
      ).root,
      p.join('/local', 'Studio'),
    );
    expect(
      StudioLayout.resolve(
        paths: paths,
        settings: AppSettings.defaults.copyWith(studioRoot: '/big/disk'),
        os: HostOs.linux,
      ).root,
      '/big/disk',
    );
  });

  test('managed builds live under the install', () {
    const StudioLayout layout = StudioLayout(root: '/s', os: HostOs.windows);
    expect(
      layout.buildDir('main', version),
      p.join('/s', 'main', 'builds', '0.690.0.6900613'),
    );
    expect(
      layout.stagingDir('main', version),
      p.join('/s', 'main', 'builds', '.0.690.0.6900613.staging'),
    );
    expect(
      layout.replacedDir('main', version),
      p.join('/s', 'main', 'builds', '.0.690.0.6900613.replaced'),
    );
    expect(
      layout.downloadsDir(version),
      p.join('/s', '.downloads', '0.690.0.6900613'),
    );
  });

  test('windows builds are their own folder and payload', () {
    const StudioLayout layout = StudioLayout(root: '/s', os: HostOs.windows);
    final String dir = layout.buildDir('main', version);
    final StudioBuild build = buildAt(layout.buildPathIn(dir));
    expect(build.path, dir);
    expect(layout.buildDirOf(build), dir);
    expect(layout.payloadDir(build), dir);
    expect(layout.studioExecutable(build), p.join(dir, 'RobloxStudioBeta.exe'));
    expect(
      layout.launcherExecutable(build),
      p.join(dir, 'RobloxStudioLauncherBeta.exe'),
    );
  });

  test('macos builds point at the bundle inside the build folder', () {
    const StudioLayout layout = StudioLayout(root: '/s', os: HostOs.macos);
    final String dir = layout.buildDir('main', version);
    final StudioBuild build = buildAt(layout.buildPathIn(dir));
    expect(build.path, p.join(dir, 'RobloxStudio.app'));
    expect(layout.buildDirOf(build), dir);
    expect(
      layout.payloadDir(build),
      p.join(dir, 'RobloxStudio.app', 'Contents', 'MacOS'),
    );
    expect(
      layout.studioExecutable(build),
      p.join(dir, 'RobloxStudio.app', 'Contents', 'MacOS', 'RobloxStudio'),
    );
  });

  test('the volume is the drive on windows', () {
    expect(
      const StudioLayout(
        root: r'C:\Users\João\AppData\Local\RMLLauncher\Studio',
        os: HostOs.windows,
      ).volume,
      'C:',
    );
    expect(const StudioLayout(root: '/s', os: HostOs.linux).volume, '/s');
  });

  test('only paths under the root are owned', () {
    const StudioLayout layout = StudioLayout(root: '/s', os: HostOs.macos);
    expect(layout.owns(p.join('/s', 'main', 'builds', '1')), isTrue);
    expect(layout.owns('/Applications/RobloxStudio.app'), isFalse);
    expect(layout.owns('/s'), isFalse);
  });
}
