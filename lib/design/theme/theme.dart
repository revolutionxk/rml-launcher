import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/motion/motion.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/theme/typography.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

final class ThemeData {
  const ThemeData({
    required this.palette,
    required this.brightness,
    required this.colors,
    required this.typography,
    required this.motion,
  });

  factory ThemeData.resolve({
    required Palette palette,
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
    return ThemeData(
      palette: palette,
      brightness: brightness,
      colors: ThemeColors.of(palette, brightness),
      typography: Typography.standard,
      motion: Motion(reduced: reduced),
    );
  }

  final Palette palette;
  final Brightness brightness;
  final ThemeColors colors;
  final Typography typography;
  final Motion motion;

  @override
  bool operator ==(Object other) =>
      other is ThemeData &&
      other.palette == palette &&
      other.brightness == brightness &&
      other.motion.reduced == motion.reduced;

  @override
  int get hashCode => Object.hash(palette, brightness, motion.reduced);
}

class Theme extends InheritedWidget {
  const Theme({required this.data, required super.child, super.key});

  final ThemeData data;

  static ThemeData of(BuildContext context) {
    final Theme? theme = context.dependOnInheritedWidgetOfExactType<Theme>();
    assert(theme != null, 'No Theme above this context');
    return theme!.data;
  }

  @override
  bool updateShouldNotify(Theme oldWidget) => data != oldWidget.data;
}
