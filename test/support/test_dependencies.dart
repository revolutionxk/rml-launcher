import 'package:rml_launcher/core/di/app_dependencies.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/platform/window_chrome.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';

import 'fake_native_service.dart';
import 'fake_window_chrome.dart';
import 'memory_json_store.dart';

AppDependencies testDependencies({
  AppSettings settings = AppSettings.defaults,
  MemoryJsonStore? store,
  WindowChrome? windowChrome,
  NativeService? native,
}) {
  final MemoryJsonStore memory = store ?? MemoryJsonStore();
  return AppDependencies(
    paths: const AppPaths(dataDir: '/tmp/rml-test', localDir: '/tmp/rml-test'),
    store: memory,
    settingsRepository: SettingsRepository(memory),
    initialSettings: settings,
    windowChrome: windowChrome ?? FakeWindowChrome(),
    native: native ?? FakeNativeService(),
  );
}
