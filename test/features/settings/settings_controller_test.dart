import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/data/settings_repository.dart';
import 'package:rml_launcher/features/settings/settings_controller.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

import '../../support/memory_json_store.dart';
import '../../support/test_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => LocaleSettings.setLocale(AppLocale.en));

  test('changes are applied and saved', () async {
    final MemoryJsonStore store = MemoryJsonStore();
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        appDependenciesProvider.overrideWithValue(
          testDependencies(store: store),
        ),
      ],
    );
    final SettingsController controller = container.read(
      settingsControllerProvider.notifier,
    );

    await controller.setPalette(RmlPalette.stoneAndSand);
    await controller.setMode(ModeSetting.dark);
    await controller.setReduceMotion(ReduceMotionSetting.on);

    final AppSettings state = container.read(settingsControllerProvider);
    expect(state.palette, RmlPalette.stoneAndSand);
    expect(state.mode, ModeSetting.dark);
    expect(state.reduceMotion, ReduceMotionSetting.on);
    expect(await SettingsRepository(store).load(), state);
  });

  test('changing the language switches the active locale', () async {
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        appDependenciesProvider.overrideWithValue(testDependencies()),
      ],
    );
    await container
        .read(settingsControllerProvider.notifier)
        .setLanguage(AppLanguage.portuguese);
    expect(LocaleSettings.currentLocale, AppLocale.ptBr);
    expect(
      container.read(settingsControllerProvider).language,
      AppLanguage.portuguese,
    );
  });

  test('a store without settings loads defaults', () async {
    expect(
      await SettingsRepository(MemoryJsonStore()).load(),
      AppSettings.defaults,
    );
  });
}
