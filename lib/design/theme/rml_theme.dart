import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/motion/rml_motion.dart';
import 'package:rml_launcher/design/theme/rml_typography.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

final class RmlThemeData {
  const RmlThemeData({
    required this.palette,
    required this.brightness,
    required this.colors,
    required this.typography,
    required this.motion,
  });

  factory RmlThemeData.resolve({
    required RmlPalette palette,
    required ModeSetting mode,
    required ReduceMotionSetting reduceMotion,
    required Brightness platformBrightness,
    required bool platformDisablesAnimations,
  }) {
    final Brightness brightness = switch (mode) {
      ModeSetting.system => platformBrightness,
      ModeSetting.dark => Brightness.dark,
      ModeSetting.light => Brightness.light,
    };
    final bool reduced = switch (reduceMotion) {
      ReduceMotionSetting.system => platformDisablesAnimations,
      ReduceMotionSetting.on => true,
      ReduceMotionSetting.off => false,
    };
    return RmlThemeData(
      palette: palette,
      brightness: brightness,
      colors: RmlColors.of(palette, brightness),
      typography: RmlTypography.standard,
      motion: RmlMotion(reduced: reduced),
    );
  }

  final RmlPalette palette;
  final Brightness brightness;
  final RmlColors colors;
  final RmlTypography typography;
  final RmlMotion motion;

  @override
  bool operator ==(Object other) =>
      other is RmlThemeData &&
      other.palette == palette &&
      other.brightness == brightness &&
      other.motion.reduced == motion.reduced;

  @override
  int get hashCode => Object.hash(palette, brightness, motion.reduced);
}

class RmlTheme extends InheritedWidget {
  const RmlTheme({required this.data, required super.child, super.key});

  final RmlThemeData data;

  static RmlThemeData of(BuildContext context) {
    final RmlTheme? theme = context
        .dependOnInheritedWidgetOfExactType<RmlTheme>();
    assert(theme != null, 'No RmlTheme above this context');
    return theme!.data;
  }

  @override
  bool updateShouldNotify(RmlTheme oldWidget) => data != oldWidget.data;
}
