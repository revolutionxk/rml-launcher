import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/motion/motion.dart';
import 'package:rml_launcher/design/theme/theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

ThemeData resolve({
  ModeSetting mode = ModeSetting.system,
  ReduceMotionSetting reduceMotion = ReduceMotionSetting.system,
  Brightness platformBrightness = Brightness.dark,
  bool platformDisablesAnimations = false,
}) => ThemeData.resolve(
  palette: Palette.blackAndBlue,
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
      same(ThemeColors.blackAndBlueLight),
    );
    expect(
      resolve(
        mode: ModeSetting.dark,
        platformBrightness: Brightness.light,
      ).colors,
      same(ThemeColors.blackAndBlueDark),
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
    const Motion reduced = Motion(reduced: true);
    expect(reduced.press, Duration.zero);
    expect(reduced.lg, Duration.zero);
    expect(reduced.fade, const Duration(milliseconds: 150));
    const Motion full = Motion(reduced: false);
    expect(full.press, const Duration(milliseconds: 100));
    expect(full.hoverIn, const Duration(milliseconds: 60));
    expect(full.hoverOut, const Duration(milliseconds: 140));
    expect(full.md, const Duration(milliseconds: 200));
  });

  test('theme data compares by palette, brightness and motion', () {
    expect(resolve(), resolve());
    expect(resolve() == resolve(mode: ModeSetting.light), isFalse);
  });

  testWidgets('Theme.of finds the nearest theme', (WidgetTester tester) async {
    final ThemeData data = resolve(mode: ModeSetting.light);
    late ThemeData found;
    await tester.pumpWidget(
      Theme(
        data: data,
        child: Builder(
          builder: (BuildContext context) {
            found = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, same(data));
  });
}
