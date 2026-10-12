import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/components/rml_segmented.dart';

import '../../support/component_harness.dart';

void main() {
  testWidgets('tapping a segment reports its value', (
    WidgetTester tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      componentHarness(
        RmlSegmented<String>(
          semanticLabel: 'Mode',
          selected: 'dark',
          onChanged: (String value) => chosen = value,
          segments: const <RmlSegment<String>>[
            RmlSegment<String>(value: 'system', label: 'System'),
            RmlSegment<String>(value: 'dark', label: 'Dark'),
            RmlSegment<String>(value: 'light', label: 'Light'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Light'));
    expect(chosen, 'light');
  });

  testWidgets('the selected segment is marked selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      componentHarness(
        RmlSegmented<String>(
          semanticLabel: 'Mode',
          selected: 'dark',
          onChanged: (String value) {},
          segments: const <RmlSegment<String>>[
            RmlSegment<String>(value: 'dark', label: 'Dark'),
            RmlSegment<String>(value: 'light', label: 'Light'),
          ],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Dark')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Light')),
      isSemantics(isSelected: false),
    );
  });
}
