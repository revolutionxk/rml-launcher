import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';

Future<Result<void>> moveCarryOver(
  Iterable<String> paths, {
  required String from,
  required String to,
}) async {
  if (p.equals(from, to)) {
    return const Result<void>.err(
      ValidationFailure(message: 'Carry-over source and target are the same.'),
    );
  }
  final List<String> moved = <String>[];
  for (final String relative in paths) {
    final List<String> parts = relative.split('/');
    final String source = p.joinAll(<String>[from, ...parts]);
    final String target = p.joinAll(<String>[to, ...parts]);
    final FileSystemEntityType type = FileSystemEntity.typeSync(
      source,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      continue;
    }
    final FileSystemEntity entity = switch (type) {
      FileSystemEntityType.directory => Directory(source),
      FileSystemEntityType.link => Link(source),
      _ => File(source),
    };
    try {
      await deleteQuietly(target);
      await Directory(p.dirname(target)).create(recursive: true);
      await renameWithRetry(entity, target);
      moved.add(relative);
    } on FileSystemException catch (error, stackTrace) {
      await _restore(moved.reversed, from: from, to: to);
      return Result<void>.err(
        IoFailure(path: source, cause: error, stackTrace: stackTrace),
      );
    }
  }
  return const Result<void>.ok(null);
}

Future<void> _restore(
  Iterable<String> done, {
  required String from,
  required String to,
}) async {
  for (final String relative in done) {
    final List<String> parts = relative.split('/');
    final String moved = p.joinAll(<String>[to, ...parts]);
    final FileSystemEntity entity = FileSystemEntity.isDirectorySync(moved)
        ? Directory(moved)
        : File(moved);
    try {
      await renameWithRetry(entity, p.joinAll(<String>[from, ...parts]));
    } on FileSystemException {
      continue;
    }
  }
}
