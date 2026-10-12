import 'dart:io';

import 'package:path/path.dart' as p;

enum HostOs { windows, macos, linux }

HostOs currentHostOs() {
  if (Platform.isWindows) {
    return HostOs.windows;
  }
  if (Platform.isMacOS) {
    return HostOs.macos;
  }
  return HostOs.linux;
}

final class AppPaths {
  const AppPaths({required this.dataDir});

  factory AppPaths.resolve({
    required HostOs os,
    required Map<String, String> environment,
  }) {
    final String dataDir = switch (os) {
      HostOs.windows => p.windows.join(
        _required(environment, 'APPDATA'),
        _folder,
      ),
      HostOs.macos => p.posix.join(
        _required(environment, 'HOME'),
        'Library',
        'Application Support',
        _folder,
      ),
      HostOs.linux => p.posix.join(_linuxDataHome(environment), _folder),
    };
    return AppPaths(dataDir: dataDir);
  }

  static const String _folder = 'RMLLauncher';

  final String dataDir;

  static String _linuxDataHome(Map<String, String> environment) {
    final String? xdg = environment['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return xdg;
    }
    return p.posix.join(_required(environment, 'HOME'), '.local', 'share');
  }

  static String _required(Map<String, String> environment, String key) {
    final String? value = environment[key];
    if (value == null || value.isEmpty) {
      throw StateError('$key is not set');
    }
    return value;
  }
}
