import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rml_launcher/core/config/app_info.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/components/segmented_control.dart';
import 'package:rml_launcher/design/layout/page_scaffold.dart';
import 'package:rml_launcher/design/theme/theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/colors.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/settings_controller.dart';
import 'package:rml_launcher/features/settings/view/settings_section.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Translations t = context.t;
    final ThemeData theme = Theme.of(context);
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
    final String? nativeVersion = ref.watch(nativeServiceProvider).version;
    return PageScaffold(
      title: t.nav.settings,
      children: <Widget>[
        SettingsSection(
          title: t.settings.appearance,
          children: <Widget>[
            SettingsRow(
              label: t.settings.colorTheme,
              control: SegmentedControl<Palette>(
                semanticLabel: t.settings.colorTheme,
                selected: settings.palette,
                onChanged: controller.setPalette,
                segments: <Segment<Palette>>[
                  Segment<Palette>(
                    value: Palette.blackAndBlue,
                    label: t.settings.palette.blackAndBlue,
                  ),
                  Segment<Palette>(
                    value: Palette.stoneAndSand,
                    label: t.settings.palette.stoneAndSand,
                  ),
                  Segment<Palette>(
                    value: Palette.studioGrey,
                    label: t.settings.palette.studioGrey,
                  ),
                ],
              ),
            ),
            SettingsRow(
              label: t.settings.mode,
              control: SegmentedControl<ModeSetting>(
                semanticLabel: t.settings.mode,
                selected: settings.mode,
                onChanged: controller.setMode,
                segments: <Segment<ModeSetting>>[
                  Segment<ModeSetting>(
                    value: ModeSetting.system,
                    label: t.settings.modes.system,
                  ),
                  Segment<ModeSetting>(
                    value: ModeSetting.dark,
                    label: t.settings.modes.dark,
                  ),
                  Segment<ModeSetting>(
                    value: ModeSetting.light,
                    label: t.settings.modes.light,
                  ),
                ],
              ),
            ),
            SettingsRow(
              label: t.settings.reduceMotion,
              control: SegmentedControl<ReduceMotionSetting>(
                semanticLabel: t.settings.reduceMotion,
                selected: settings.reduceMotion,
                onChanged: controller.setReduceMotion,
                segments: <Segment<ReduceMotionSetting>>[
                  Segment<ReduceMotionSetting>(
                    value: ReduceMotionSetting.system,
                    label: t.settings.motion.system,
                  ),
                  Segment<ReduceMotionSetting>(
                    value: ReduceMotionSetting.on,
                    label: t.settings.motion.turnedOn,
                  ),
                  Segment<ReduceMotionSetting>(
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
              control: SegmentedControl<AppLanguage>(
                semanticLabel: t.settings.language,
                selected: language,
                onChanged: controller.setLanguage,
                segments: <Segment<AppLanguage>>[
                  Segment<AppLanguage>(
                    value: AppLanguage.english,
                    label: t.settings.languages.english,
                  ),
                  Segment<AppLanguage>(
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
            if (nativeVersion != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.settings.nativeVersion(version: nativeVersion),
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
