import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';

final class SettingsRepository {
  const SettingsRepository(this._store);

  static const String documentName = 'settings';

  final JsonStore _store;

  Future<AppSettings> load() async {
    final Result<JsonMap?> result = await _store.read(documentName);
    final JsonMap? json = result.valueOrNull;
    return json == null ? AppSettings.defaults : AppSettings.fromJson(json);
  }

  Future<Result<void>> save(AppSettings settings) =>
      _store.write(documentName, settings.toJson());
}
