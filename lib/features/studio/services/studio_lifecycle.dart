import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

final class StudioLifecycle {
  StudioLifecycle({
    required this._layout,
    required this._discovery,
    required this._updates,
    required this._running,
    this.hourly = const Duration(hours: 1),
  });

  final Duration hourly;
  final StudioLayout _layout;
  final DiscoveryService _discovery;
  final UpdateService _updates;
  final RunningWatcher _running;
  Timer? _timer;

  Future<void> start() async {
    await removeLeftovers();
    await _discovery.refresh();
    _running.start();
    unawaited(_updates.checkForUpdates());
    _timer?.cancel();
    _timer = Timer.periodic(
      hourly,
      (_) => unawaited(_updates.checkForUpdates()),
    );
  }

  Future<void> onFocus() async {
    await _discovery.refresh();
    unawaited(_updates.checkIfDue());
  }

  void setVisible({required bool visible}) =>
      _running.setVisible(visible: visible);

  Future<void> removeLeftovers() async {
    final Directory root = Directory(_layout.root);
    if (!root.existsSync()) {
      return;
    }
    final List<FileSystemEntity> installs;
    try {
      installs = root.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final FileSystemEntity install in installs) {
      if (install is! Directory) {
        continue;
      }
      try {
        await _clearInstall(Directory(p.join(install.path, 'builds')));
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<void> _clearInstall(Directory builds) async {
    if (!builds.existsSync()) {
      return;
    }
    for (final FileSystemEntity entry in builds.listSync(followLinks: false)) {
      final String name = p.basename(entry.path);
      if (!name.startsWith('.')) {
        continue;
      }
      try {
        if (name.endsWith('.staging')) {
          await deleteQuietly(entry.path);
        } else if (name.endsWith('.replaced')) {
          await _settleReplaced(builds.path, entry);
        }
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<void> _settleReplaced(String builds, FileSystemEntity entry) async {
    final String name = p.basename(entry.path);
    final String version = name.substring(1, name.length - '.replaced'.length);
    final String target = p.join(builds, version);
    if (FileSystemEntity.typeSync(target, followLinks: false) ==
        FileSystemEntityType.notFound) {
      await renameWithRetry(entry, target);
    } else {
      await deleteQuietly(entry.path);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _running.dispose();
  }
}
