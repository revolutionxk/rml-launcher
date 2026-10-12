import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/motion/rml_motion.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

RmlThemeData resolve({
  ModeSetting mode = ModeSetting.system,
  ReduceMotionSetting reduceMotion = ReduceMotionSetting.system,
  Brightness platformBrightness = Brightness.dark,
  bool platformDisablesAnimations = false,
}) => RmlThemeData.resolve(
  palette: RmlPalette.blackAndBlue,
  mode: mode,
  reduceMotion: reduceMotion,
  platformBrightness: platformBrightness,
  platformDisablesAnimations: platformDisablesAnimations,
);

void main() {
  test('mode system follows the platform brightness', () {
    expect(
      resolve(platformBrightness: Brightness.light).brightness,
      Brightness.light,
    );
    expect(resolve().brightness, Brightness.dark);
  });

  test('an explicit mode wins over the platform', () {
    expect(
      resolve(mode: ModeSetting.light).colors,
      same(RmlColors.blackAndBlueLight),
    );
    expect(
      resolve(
        mode: ModeSetting.dark,
        platformBrightness: Brightness.light,
      ).colors,
      same(RmlColors.blackAndBlueDark),
    );
  });

  test('reduce motion system follows the platform', () {
    expect(resolve(platformDisablesAnimations: true).motion.reduced, isTrue);
    expect(resolve().motion.reduced, isFalse);
    expect(
      resolve(
        reduceMotion: ReduceMotionSetting.off,
        platformDisablesAnimations: true,
      ).motion.reduced,
      isFalse,
    );
    expect(
      resolve(reduceMotion: ReduceMotionSetting.on).motion.reduced,
      isTrue,
    );
  });

  test('reduced motion zeroes movement but keeps fades', () {
    const RmlMotion reduced = RmlMotion(reduced: true);
    expect(reduced.press, Duration.zero);
    expect(reduced.lg, Duration.zero);
    expect(reduced.fade, const Duration(milliseconds: 150));
    const RmlMotion full = RmlMotion(reduced: false);
    expect(full.press, const Duration(milliseconds: 100));
    expect(full.hoverIn, const Duration(milliseconds: 60));
    expect(full.hoverOut, const Duration(milliseconds: 140));
    expect(full.md, const Duration(milliseconds: 200));
  });

  test('theme data compares by palette, brightness and motion', () {
    expect(resolve(), resolve());
    expect(resolve() == resolve(mode: ModeSetting.light), isFalse);
  });

  testWidgets('RmlTheme.of finds the nearest theme', (
    WidgetTester tester,
  ) async {
    final RmlThemeData data = resolve(mode: ModeSetting.light);
    late RmlThemeData found;
    await tester.pumpWidget(
      RmlTheme(
        data: data,
        child: Builder(
          builder: (BuildContext context) {
            found = RmlTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, same(data));
  });
}
