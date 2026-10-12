import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';

final class InstallRepository {
  const InstallRepository(this._store);

  static const String documentName = 'installs';
  static const List<Duration> _readRetries = <Duration>[
    Duration(milliseconds: 100),
    Duration(milliseconds: 300),
  ];

  final JsonStore _store;

  Future<Result<StudioLibrary>> load() async {
    Result<JsonMap?> read = await _store.read(documentName);
    for (final Duration wait in _readRetries) {
      if (read.failureOrNull is! IoFailure) {
        break;
      }
      await Future<void>.delayed(wait);
      read = await _store.read(documentName);
    }
    return switch (read) {
      Err<JsonMap?>(:final AppFailure failure) => Result<StudioLibrary>.err(
        failure,
      ),
      Ok<JsonMap?>(value: null) => const Result<StudioLibrary>.ok(
        StudioLibrary.empty,
      ),
      Ok<JsonMap?>(:final JsonMap value) => _decode(value),
    };
  }

  Future<Result<void>> save(StudioLibrary library) =>
      _store.write(documentName, library.toJson());

  static Result<StudioLibrary> _decode(JsonMap json) {
    final Object? schema = json['schema'];
    if (schema is num && schema > StudioLibrary.schema) {
      return const Result<StudioLibrary>.err(
        ValidationFailure(
          message: 'The install list was saved by a newer RML Launcher.',
        ),
      );
    }
    return Result<StudioLibrary>.ok(StudioLibrary.fromJson(json));
  }
}
