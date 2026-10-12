import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rml_launcher/core/config/app_info.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/components/rml_segmented.dart';
import 'package:rml_launcher/design/layout/page_scaffold.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/settings_controller.dart';
import 'package:rml_launcher/features/settings/view/settings_section.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Translations t = context.t;
    final RmlThemeData theme = RmlTheme.of(context);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final AppLanguage language =
        settings.language ??
        AppLanguage.fromTag(
          TranslationProvider.of(context).locale.languageTag,
        ) ??
        AppLanguage.english;
    return PageScaffold(
      title: t.nav.settings,
      children: <Widget>[
        SettingsSection(
          title: t.settings.appearance,
          children: <Widget>[
            SettingsRow(
              label: t.settings.colorTheme,
              control: RmlSegmented<RmlPalette>(
                semanticLabel: t.settings.colorTheme,
                selected: settings.palette,
                onChanged: controller.setPalette,
                segments: <RmlSegment<RmlPalette>>[
                  RmlSegment<RmlPalette>(
                    value: RmlPalette.blackAndBlue,
                    label: t.settings.palette.blackAndBlue,
                  ),
                  RmlSegment<RmlPalette>(
                    value: RmlPalette.stoneAndSand,
                    label: t.settings.palette.stoneAndSand,
                  ),
                  RmlSegment<RmlPalette>(
                    value: RmlPalette.studioGrey,
                    label: t.settings.palette.studioGrey,
                  ),
                ],
              ),
            ),
            SettingsRow(
              label: t.settings.mode,
              control: RmlSegmented<ModeSetting>(
                semanticLabel: t.settings.mode,
                selected: settings.mode,
                onChanged: controller.setMode,
                segments: <RmlSegment<ModeSetting>>[
                  RmlSegment<ModeSetting>(
                    value: ModeSetting.system,
                    label: t.settings.modes.system,
                  ),
                  RmlSegment<ModeSetting>(
                    value: ModeSetting.dark,
                    label: t.settings.modes.dark,
                  ),
                  RmlSegment<ModeSetting>(
                    value: ModeSetting.light,
                    label: t.settings.modes.light,
                  ),
                ],
              ),
            ),
            SettingsRow(
              label: t.settings.reduceMotion,
              control: RmlSegmented<ReduceMotionSetting>(
                semanticLabel: t.settings.reduceMotion,
                selected: settings.reduceMotion,
                onChanged: controller.setReduceMotion,
                segments: <RmlSegment<ReduceMotionSetting>>[
                  RmlSegment<ReduceMotionSetting>(
                    value: ReduceMotionSetting.system,
                    label: t.settings.motion.system,
                  ),
                  RmlSegment<ReduceMotionSetting>(
                    value: ReduceMotionSetting.on,
                    label: t.settings.motion.turnedOn,
                  ),
                  RmlSegment<ReduceMotionSetting>(
                    value: ReduceMotionSetting.off,
                    label: t.settings.motion.turnedOff,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: t.settings.language,
          children: <Widget>[
            SettingsRow(
              label: t.settings.language,
              control: RmlSegmented<AppLanguage>(
                semanticLabel: t.settings.language,
                selected: language,
                onChanged: controller.setLanguage,
                segments: <RmlSegment<AppLanguage>>[
                  RmlSegment<AppLanguage>(
                    value: AppLanguage.english,
                    label: t.settings.languages.english,
                  ),
                  RmlSegment<AppLanguage>(
                    value: AppLanguage.portuguese,
                    label: t.settings.languages.portuguese,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: t.settings.about,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t.settings.appVersion(version: AppInfo.version),
                style: theme.typography.body.copyWith(
                  color: theme.colors.text2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t.settings.nativeVersion(
                  version: ref.watch(nativeServiceProvider).version,
                ),
                style: theme.typography.body.copyWith(
                  color: theme.colors.text2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
