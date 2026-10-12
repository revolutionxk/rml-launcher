import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';

typedef JsonMap = Map<String, Object?>;

abstract interface class JsonStore {
  Future<Result<JsonMap?>> read(String name);

  Future<Result<void>> write(String name, JsonMap value);
}

final class FileJsonStore implements JsonStore {
  FileJsonStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;
  final Map<String, Future<void>> _pending = <String, Future<void>>{};

  File _file(String name) => File(p.join(directory.path, '$name.json'));

  @override
  Future<Result<JsonMap?>> read(String name) =>
      _enqueue(name, () => _readNow(name));

  @override
  Future<Result<void>> write(String name, JsonMap value) =>
      _enqueue(name, () => _writeNow(name, value));

  Future<T> _enqueue<T>(String name, Future<T> Function() action) {
    final Future<void> previous = _pending[name] ?? Future<void>.value();
    final Future<T> outcome = previous.then((_) => action());
    _pending[name] = outcome.then<void>((_) {}, onError: (_) {});
    return outcome;
  }

  Future<Result<JsonMap?>> _readNow(String name) async {
    final File file = _file(name);
    try {
      if (!file.existsSync()) {
        return const Result<JsonMap?>.ok(null);
      }
      final Object? decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (decoded is! Map<String, Object?>) {
        return await _setAside(file);
      }
      return Result<JsonMap?>.ok(decoded);
    } on FormatException {
      return _setAside(file);
    } on FileSystemException catch (error, stackTrace) {
      return Result<JsonMap?>.err(
        IoFailure(path: file.path, cause: error, stackTrace: stackTrace),
      );
    }
  }

  Future<Result<void>> _writeNow(String name, JsonMap value) async {
    final File file = _file(name);
    final String encoded;
    try {
      encoded = const JsonEncoder.withIndent('  ').convert(value);
    } on JsonUnsupportedObjectError catch (error, stackTrace) {
      return Result<void>.err(
        ValidationFailure(
          message: '$name cannot be encoded as JSON',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    final File temp = File('${file.path}.$pid.tmp');
    try {
      await directory.create(recursive: true);
      final RandomAccessFile handle = await temp.open(mode: FileMode.write);
      try {
        await handle.writeString(encoded);
        await handle.flush();
      } finally {
        await handle.close();
      }
      await renameWithRetry(temp, file.path);
      return const Result<void>.ok(null);
    } on FileSystemException catch (error, stackTrace) {
      await _discard(temp);
      return Result<void>.err(
        IoFailure(path: file.path, cause: error, stackTrace: stackTrace),
      );
    }
  }

  Future<void> _discard(File temp) async {
    try {
      await temp.delete();
    } on FileSystemException {
      return;
    }
  }

  Future<Result<JsonMap?>> _setAside(File file) async {
    final String stamp = _clock().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    try {
      await file.rename('${file.path}.corrupt-$stamp');
      return const Result<JsonMap?>.ok(null);
    } on FileSystemException catch (error, stackTrace) {
      return Result<JsonMap?>.err(
        IoFailure(path: file.path, cause: error, stackTrace: stackTrace),
      );
    }
  }
}
