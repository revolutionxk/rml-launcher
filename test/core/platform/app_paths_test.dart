import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';

void main() {
  test('windows uses roaming app data and local app data', () {
    final AppPaths paths = AppPaths.resolve(
      os: HostOs.windows,
      environment: <String, String>{
        'APPDATA': r'C:\Users\João\AppData\Roaming',
        'LOCALAPPDATA': r'C:\Users\João\AppData\Local',
      },
    );
    expect(paths.dataDir, r'C:\Users\João\AppData\Roaming\RMLLauncher');
    expect(paths.localDir, r'C:\Users\João\AppData\Local\RMLLauncher');
  });

  test('macos uses application support', () {
    final AppPaths paths = AppPaths.resolve(
      os: HostOs.macos,
      environment: <String, String>{'HOME': '/Users/ana'},
    );
    expect(paths.dataDir, '/Users/ana/Library/Application Support/RMLLauncher');
    expect(paths.localDir, paths.dataDir);
  });

  test('linux prefers XDG_DATA_HOME', () {
    final AppPaths paths = AppPaths.resolve(
      os: HostOs.linux,
      environment: <String, String>{
        'HOME': '/home/ana',
        'XDG_DATA_HOME': '/data',
      },
    );
    expect(paths.dataDir, '/data/RMLLauncher');
  });

  test('linux falls back to ~/.local/share when XDG_DATA_HOME is empty', () {
    final AppPaths paths = AppPaths.resolve(
      os: HostOs.linux,
      environment: <String, String>{'HOME': '/home/ana', 'XDG_DATA_HOME': ''},
    );
    expect(paths.dataDir, '/home/ana/.local/share/RMLLauncher');
  });

  test('a missing home is a state error', () {
    expect(
      () => AppPaths.resolve(os: HostOs.macos, environment: <String, String>{}),
      throwsStateError,
    );
  });
}
