import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/layout/page_scaffold.dart';

import '../../support/component_harness.dart';

void main() {
  testWidgets('page titles use the 20/26 title style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      componentHarness(const PageScaffold(title: 'Library')),
    );
    final TextStyle style = tester.widget<Text>(find.text('Library')).style!;
    expect(style.fontSize, 20);
    expect(style.height, 26 / 20);
  });
}
