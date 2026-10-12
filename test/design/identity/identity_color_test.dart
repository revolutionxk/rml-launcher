import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/design/identity/monogram.dart';
import 'package:rml_launcher/design/tokens/contrast.dart';

void main() {
  for (final IdentityColor color in IdentityColor.values) {
    for (final Brightness brightness in Brightness.values) {
      test('${color.name} ink reaches 4.5:1 in ${brightness.name} mode', () {
        expect(
          contrastRatio(IdentityColor.ink(brightness), color.fill(brightness)),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test('monograms use the first character, upper case', () {
    expect(monogramFor('Main'), 'M');
    expect(monogramFor('  legacy '), 'L');
    expect(monogramFor('éclair'), 'É');
    expect(monogramFor(''), '?');
  });
}
