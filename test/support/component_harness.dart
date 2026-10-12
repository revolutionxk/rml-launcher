import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

Widget componentHarness(
  Widget child, {
  Brightness brightness = Brightness.dark,
}) {
  final RmlThemeData data = RmlThemeData.resolve(
    palette: RmlPalette.blackAndBlue,
    mode: brightness == Brightness.dark ? ModeSetting.dark : ModeSetting.light,
    reduceMotion: ReduceMotionSetting.off,
    platformBrightness: brightness,
    platformDisablesAnimations: false,
  );
  return WidgetsApp(
    color: data.colors.accent,
    builder: (BuildContext context, Widget? navigator) => RmlTheme(
      data: data,
      child: DefaultTextStyle(
        style: data.typography.body.copyWith(color: data.colors.text),
        child: Center(child: child),
      ),
    ),
  );
}
