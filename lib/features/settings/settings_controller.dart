import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

part 'settings_controller.g.dart';

@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(appDependenciesProvider).initialSettings;

  Future<void> setPalette(RmlPalette palette) =>
      _update(state.copyWith(palette: palette));

  Future<void> setMode(ModeSetting mode) => _update(state.copyWith(mode: mode));

  Future<void> setReduceMotion(ReduceMotionSetting reduceMotion) =>
      _update(state.copyWith(reduceMotion: reduceMotion));

  Future<void> setLanguage(AppLanguage language) async {
    await LocaleSettings.setLocaleRaw(language.tag);
    await _update(state.copyWith(language: language));
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(appDependenciesProvider).settingsRepository.save(next);
  }
}
