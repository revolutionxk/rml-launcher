import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rml_launcher/app.dart';
import 'package:rml_launcher/core/di/app_dependencies.dart';
import 'package:rml_launcher/core/di/bootstrap.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/i18n/translations.g.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDependencies dependencies = await bootstrap();
  await _applyLanguage(dependencies.initialSettings.language);
  await _configureWindow();
  runApp(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
      child: TranslationProvider(child: const LauncherApp()),
    ),
  );
}

Future<void> _applyLanguage(AppLanguage? language) async {
  if (language == null) {
    await LocaleSettings.useDeviceLocale();
    return;
  }
  await LocaleSettings.setLocaleRaw(language.tag);
}

Future<void> _configureWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(880, 600),
      center: true,
      title: 'RML Launcher',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
