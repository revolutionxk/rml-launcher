import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/components/segmented_control.dart';

import '../../support/component_harness.dart';

void main() {
  testWidgets('tapping a segment reports its value', (
    WidgetTester tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      componentHarness(
        SegmentedControl<String>(
          semanticLabel: 'Mode',
          selected: 'dark',
          onChanged: (String value) => chosen = value,
          segments: const <Segment<String>>[
            Segment<String>(value: 'system', label: 'System'),
            Segment<String>(value: 'dark', label: 'Dark'),
            Segment<String>(value: 'light', label: 'Light'),
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
        SegmentedControl<String>(
          semanticLabel: 'Mode',
          selected: 'dark',
          onChanged: (String value) {},
          segments: const <Segment<String>>[
            Segment<String>(value: 'dark', label: 'Dark'),
            Segment<String>(value: 'light', label: 'Light'),
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
