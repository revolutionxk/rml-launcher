import 'package:rml_launcher/core/di/app_dependencies.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';

import 'memory_json_store.dart';

AppDependencies testDependencies({
  AppSettings settings = AppSettings.defaults,
  MemoryJsonStore? store,
}) {
  final MemoryJsonStore memory = store ?? MemoryJsonStore();
  return AppDependencies(
    paths: const AppPaths(dataDir: '/tmp/rml-test'),
    store: memory,
    settingsRepository: SettingsRepository(memory),
    initialSettings: settings,
  );
}
