import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';

Future<Result<List<String>>> moveCarryOver(
  Iterable<String> paths, {
  required String from,
  required String to,
}) async {
  if (p.equals(from, to)) {
    return const Result<List<String>>.err(
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
      final Result<void> undone = await undoCarryOver(
        moved,
        from: from,
        to: to,
      );
      return Result<List<String>>.err(
        undone.failureOrNull ??
            IoFailure(path: source, cause: error, stackTrace: stackTrace),
      );
    }
  }
  return Result<List<String>>.ok(moved);
}

Future<Result<void>> undoCarryOver(
  Iterable<String> moved, {
  required String from,
  required String to,
}) async {
  AppFailure? failure;
  for (final String relative in moved.toList().reversed) {
    final List<String> parts = relative.split('/');
    final String current = p.joinAll(<String>[to, ...parts]);
    final String original = p.joinAll(<String>[from, ...parts]);
    final FileSystemEntity entity = FileSystemEntity.isDirectorySync(current)
        ? Directory(current)
        : File(current);
    try {
      await Directory(p.dirname(original)).create(recursive: true);
      await renameWithRetry(entity, original);
    } on FileSystemException catch (error, stackTrace) {
      failure ??= IoFailure(
        path: current,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
  return failure == null
      ? const Result<void>.ok(null)
      : Result<void>.err(failure);
}
