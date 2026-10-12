import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

enum AppLanguage {
  english('en'),
  portuguese('pt-BR');

  const AppLanguage(this.tag);

  final String tag;

  static AppLanguage? fromTag(String? tag) {
    for (final AppLanguage language in values) {
      if (language.tag == tag) {
        return language;
      }
    }
    return null;
  }
}

final class AppSettings {
  const AppSettings({
    required this.palette,
    required this.mode,
    required this.reduceMotion,
    this.language,
    this.studioRoot,
    this.installUpdatesBeforeLaunch = false,
  });

  factory AppSettings.fromJson(JsonMap json) => AppSettings(
    palette: _byName(Palette.values, json['palette'], defaults.palette),
    mode: _byName(ModeSetting.values, json['mode'], defaults.mode),
    reduceMotion: _byName(
      ReduceMotionSetting.values,
      json['reduceMotion'],
      defaults.reduceMotion,
    ),
    language: AppLanguage.fromTag(
      json['language'] is String ? json['language']! as String : null,
    ),
    studioRoot: json['studioRoot'] is String
        ? json['studioRoot']! as String
        : null,
    installUpdatesBeforeLaunch: json['installUpdatesBeforeLaunch'] == true,
  );

  static const AppSettings defaults = AppSettings(
    palette: Palette.blackAndBlue,
    mode: ModeSetting.system,
    reduceMotion: ReduceMotionSetting.system,
  );

  final Palette palette;
  final ModeSetting mode;
  final ReduceMotionSetting reduceMotion;
  final AppLanguage? language;
  final String? studioRoot;
  final bool installUpdatesBeforeLaunch;

  AppSettings copyWith({
    Palette? palette,
    ModeSetting? mode,
    ReduceMotionSetting? reduceMotion,
    AppLanguage? language,
    String? studioRoot,
    bool? installUpdatesBeforeLaunch,
  }) => AppSettings(
    palette: palette ?? this.palette,
    mode: mode ?? this.mode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    language: language ?? this.language,
    studioRoot: studioRoot ?? this.studioRoot,
    installUpdatesBeforeLaunch:
        installUpdatesBeforeLaunch ?? this.installUpdatesBeforeLaunch,
  );

  JsonMap toJson() => <String, Object?>{
    'palette': palette.name,
    'mode': mode.name,
    'reduceMotion': reduceMotion.name,
    'language': language?.tag,
    'studioRoot': studioRoot,
    'installUpdatesBeforeLaunch': installUpdatesBeforeLaunch,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.palette == palette &&
      other.mode == mode &&
      other.reduceMotion == reduceMotion &&
      other.language == language &&
      other.studioRoot == studioRoot &&
      other.installUpdatesBeforeLaunch == installUpdatesBeforeLaunch;

  @override
  int get hashCode => Object.hash(
    palette,
    mode,
    reduceMotion,
    language,
    studioRoot,
    installUpdatesBeforeLaunch,
  );

  static T _byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) {
      return fallback;
    }
    for (final T value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }
}
