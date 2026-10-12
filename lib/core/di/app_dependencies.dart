import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/platform/window_chrome.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';

final class AppDependencies {
  const AppDependencies({
    required this.paths,
    required this.store,
    required this.settingsRepository,
    required this.initialSettings,
    required this.windowChrome,
    required this.native,
  });

  final AppPaths paths;
  final JsonStore store;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final WindowChrome windowChrome;
  final NativeService native;
}
