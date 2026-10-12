import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/icons/icons.dart';

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
    expect(Icons.house.fontFamily, 'PhosphorRegular');
    expect(Icons.houseFill.fontFamily, 'PhosphorFill');
    expect(Icons.house.codePoint, Icons.houseFill.codePoint);
    expect(Icons.x.codePoint, 0xe4f6);
  });

  testWidgets('an icon renders', (WidgetTester tester) async {
    await tester.pumpWidget(componentHarness(const Icon(Icons.gearSix)));
    expect(find.byType(Icon), findsOneWidget);
  });
}
