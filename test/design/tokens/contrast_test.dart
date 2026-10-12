import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/tokens/colors.dart';
import 'package:rml_launcher/design/tokens/contrast.dart';

void main() {
  test('black on white is 21:1', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
  });

  for (final Palette palette in Palette.values) {
    for (final Brightness brightness in Brightness.values) {
      final ThemeColors colors = ThemeColors.of(palette, brightness);
      group('${palette.name} ${brightness.name}', () {
        final Map<String, Color> foregrounds = <String, Color>{
          'text': colors.text,
          'text2': colors.text2,
          'text3': colors.text3,
          'accentText': colors.accentText,
          'ok': colors.ok,
          'warn': colors.warn,
          'danger': colors.danger,
        };
        final Map<String, Color> surfaces = <String, Color>{
          'panel': colors.panel,
          'card': colors.card,
          'raised': colors.raised,
          'float': colors.float,
        };
        for (final MapEntry<String, Color> fg in foregrounds.entries) {
          for (final MapEntry<String, Color> bg in surfaces.entries) {
            test('${fg.key} on ${bg.key} reaches 4.5:1', () {
              expect(
                contrastRatio(fg.value, bg.value),
                greaterThanOrEqualTo(4.5),
              );
            });
          }
        }
        test('onAccent on accent reaches 4.5:1', () {
          expect(
            contrastRatio(colors.onAccent, colors.accent),
            greaterThanOrEqualTo(4.5),
          );
        });
      });
    }
  }
}
