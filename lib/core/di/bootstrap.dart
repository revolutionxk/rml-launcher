import 'dart:io';

import 'package:rml_launcher/core/di/app_dependencies.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/platform/window_chrome.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';

Future<AppDependencies> bootstrap() async {
  final AppPaths paths = AppPaths.resolve(
    os: currentHostOs(),
    environment: Platform.environment,
  );
  final FileJsonStore store = FileJsonStore(Directory(paths.dataDir));
  final SettingsRepository settingsRepository = SettingsRepository(store);
  final AppSettings initialSettings = await settingsRepository.load();
  return AppDependencies(
    paths: paths,
    store: store,
    settingsRepository: settingsRepository,
    initialSettings: initialSettings,
    windowChrome: const WindowManagerChrome(),
    native: const RmlNativeService(),
  );
}
