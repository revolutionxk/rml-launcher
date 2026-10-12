import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/icons/rml_icons.dart';

import '../../support/component_harness.dart';

void main() {
  test('regular and fill fonts are bundled and declared', () {
    expect(File('assets/fonts/Phosphor-Regular.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/Phosphor-Fill.ttf').existsSync(), isTrue);
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('family: PhosphorRegular'), isTrue);
    expect(pubspec.contains('family: PhosphorFill'), isTrue);
    expect(pubspec.contains('phosphor_flutter'), isFalse);
  });

  test('icons point at the bundled families', () {
    expect(RmlIcons.house.fontFamily, 'PhosphorRegular');
    expect(RmlIcons.houseFill.fontFamily, 'PhosphorFill');
    expect(RmlIcons.house.codePoint, RmlIcons.houseFill.codePoint);
    expect(RmlIcons.x.codePoint, 0xe4f6);
  });

  testWidgets('an icon renders', (WidgetTester tester) async {
    await tester.pumpWidget(componentHarness(const Icon(RmlIcons.gearSix)));
    expect(find.byType(Icon), findsOneWidget);
  });
}
