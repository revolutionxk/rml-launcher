import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';

void main() {
  test('round trips through json', () {
    const AppSettings settings = AppSettings(
      palette: RmlPalette.studioGrey,
      mode: ModeSetting.light,
      reduceMotion: ReduceMotionSetting.on,
      language: AppLanguage.portuguese,
    );
    expect(AppSettings.fromJson(settings.toJson()), settings);
  });

  test('unknown or mistyped values fall back to defaults', () {
    final AppSettings settings = AppSettings.fromJson(<String, Object?>{
      'palette': 'neon',
      'mode': 3,
      'reduceMotion': null,
      'language': 'xx',
    });
    expect(settings, AppSettings.defaults);
  });

  test('language tags map both ways', () {
    expect(AppLanguage.fromTag('pt-BR'), AppLanguage.portuguese);
    expect(AppLanguage.fromTag('en'), AppLanguage.english);
    expect(AppLanguage.fromTag(null), isNull);
  });
}
