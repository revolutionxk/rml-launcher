import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';

final class InstallRepository {
  const InstallRepository(this._store);

  static const String documentName = 'installs';

  final JsonStore _store;

  Future<StudioLibrary> load() async {
    final Result<JsonMap?> result = await _store.read(documentName);
    final JsonMap? json = result.valueOrNull;
    return json == null ? StudioLibrary.empty : StudioLibrary.fromJson(json);
  }

  Future<Result<void>> save(StudioLibrary library) =>
      _store.write(documentName, library.toJson());
}
