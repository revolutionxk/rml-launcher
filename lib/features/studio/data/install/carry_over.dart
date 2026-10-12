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
    } on FileSystemException catch (error, stackTrace) {
      return Result<void>.err(
        IoFailure(path: source, cause: error, stackTrace: stackTrace),
      );
    }
  }
  return const Result<void>.ok(null);
}
