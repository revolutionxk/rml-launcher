import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';

final class AppDependencies {
  const AppDependencies({
    required this.paths,
    required this.store,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final AppPaths paths;
  final JsonStore store;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
}
