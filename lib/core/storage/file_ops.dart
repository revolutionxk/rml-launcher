import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/async/abort_signal.dart';

bool isTransientLock(FileSystemException error) =>
    Platform.isWindows && const <int>{5, 32}.contains(error.osError?.errorCode);

Future<void> renameWithRetry(FileSystemEntity entity, String target) async {
  for (int attempt = 1; ; attempt++) {
    try {
      await entity.rename(target);
      return;
    } on FileSystemException catch (error) {
      if (attempt == 5 || !isTransientLock(error)) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 10 << attempt));
    }
  }
}

Future<void> deleteQuietly(String path) async {
  try {
    final FileSystemEntityType type = FileSystemEntity.typeSync(
      path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  } on FileSystemException {
    return;
  }
}

Future<int> treeSize(String root) async {
  int total = 0;
  await for (final FileSystemEntity entity in Directory(
    root,
  ).list(recursive: true, followLinks: false)) {
    if (entity is File) {
      total += entity.lengthSync();
    }
  }
  return total;
}

Future<bool> copyTree(
  String source,
  String target, {
  void Function(int bytes)? onBytes,
  AbortSignal? abort,
}) async {
  await Directory(target).create(recursive: true);
  await for (final FileSystemEntity entity in Directory(
    source,
  ).list(recursive: true, followLinks: false)) {
    if (abort?.isAborted ?? false) {
      return false;
    }
    final String destination = p.join(
      target,
      p.relative(entity.path, from: source),
    );
    if (entity is Directory) {
      await Directory(destination).create(recursive: true);
      continue;
    }
    await Directory(p.dirname(destination)).create(recursive: true);
    if (entity is Link) {
      await Link(destination).create(await entity.target());
    } else if (entity is File) {
      await entity.copy(destination);
      onBytes?.call(entity.lengthSync());
    }
  }
  return true;
}
