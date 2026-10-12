import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/state/value_hub.dart';
import 'package:rml_launcher/features/studio/data/install_repository.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';

final class LibraryStore {
  LibraryStore(this._repository, StudioLibrary initial, {this.loadFailure})
    : _hub = ValueHub<StudioLibrary>(initial);

  static Future<LibraryStore> open(InstallRepository repository) async =>
      switch (await repository.load()) {
        Ok<StudioLibrary>(:final StudioLibrary value) => LibraryStore(
          repository,
          value,
        ),
        Err<StudioLibrary>(:final AppFailure failure) => LibraryStore(
          repository,
          StudioLibrary.empty,
          loadFailure: failure,
        ),
      };

  final AppFailure? loadFailure;
  final InstallRepository _repository;
  final ValueHub<StudioLibrary> _hub;
  Future<void> _queue = Future<void>.value();

  StudioLibrary get value => _hub.value;

  Stream<StudioLibrary> get changes => _hub.changes;

  Stream<StudioLibrary> watch() => _hub.watch();

  Future<Result<StudioLibrary>> update(
    StudioLibrary Function(StudioLibrary current) change,
  ) {
    final Future<Result<StudioLibrary>> outcome = _queue.then((_) async {
      if (loadFailure case final AppFailure refused) {
        return Result<StudioLibrary>.err(refused);
      }
      final StudioLibrary current = _hub.value;
      final StudioLibrary next = change(current);
      if (identical(next, current)) {
        return Result<StudioLibrary>.ok(current);
      }
      _hub.value = next;
      final Result<void> saved = await _repository.save(next);
      return saved.map((_) => next);
    });
    _queue = outcome.then<void>((_) {}, onError: (Object _) {});
    return outcome;
  }

  Future<void> close() => _hub.close();
}
