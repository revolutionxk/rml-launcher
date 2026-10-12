import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/components/button.dart';

import '../../support/component_harness.dart';

void main() {
  testWidgets('tapping calls onPressed', (WidgetTester tester) async {
    int presses = 0;
    await tester.pumpWidget(
      componentHarness(Button(label: 'Launch', onPressed: () => presses++)),
    );
    await tester.tap(find.text('Launch'));
    expect(presses, 1);
  });

  testWidgets('a disabled button is announced as disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      componentHarness(const Button(label: 'Launch', onPressed: null)),
    );
    expect(
      tester.getSemantics(find.text('Launch')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
  });

  testWidgets('enter and space activate the focused button', (
    WidgetTester tester,
  ) async {
    int presses = 0;
    await tester.pumpWidget(
      componentHarness(
        Button(label: 'Launch', autofocus: true, onPressed: () => presses++),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });

  testWidgets('primary and quiet variants render', (WidgetTester tester) async {
    await tester.pumpWidget(
      componentHarness(
        const Column(
          children: <Widget>[
            Button(label: 'A', onPressed: null, variant: ButtonVariant.primary),
            Button(label: 'B', onPressed: null, variant: ButtonVariant.quiet),
          ],
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
