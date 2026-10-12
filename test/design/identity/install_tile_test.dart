import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/design/identity/install_tile.dart';
import 'package:rml_launcher/design/identity/tile_progress.dart';

import '../../support/component_harness.dart';

void main() {
  testWidgets('shows the monogram and announces the name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      componentHarness(
        const InstallTile(name: 'Main', color: IdentityColor.orange),
      ),
    );
    expect(find.text('M'), findsOneWidget);
    expect(find.bySemanticsLabel('Main'), findsOneWidget);
  });

  testWidgets('an explicit monogram wins', (WidgetTester tester) async {
    await tester.pumpWidget(
      componentHarness(
        const InstallTile(
          name: 'Roblox',
          monogram: 'Ro',
          color: IdentityColor.magenta,
        ),
      ),
    );
    expect(find.text('Ro'), findsOneWidget);
  });

  testWidgets('a glyph replaces the letters', (WidgetTester tester) async {
    await tester.pumpWidget(
      componentHarness(
        const InstallTile(
          name: 'Legacy',
          color: IdentityColor.teal,
          glyph: IconData(0xe000, fontFamily: 'Glyphs'),
        ),
      ),
    );
    expect(find.text('L'), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('running shows the status dot', (WidgetTester tester) async {
    await tester.pumpWidget(
      componentHarness(
        const InstallTile(
          name: 'Main',
          color: IdentityColor.orange,
          running: true,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('install-tile-dot')),
      findsOneWidget,
    );
  });

  testWidgets('progress paints the ring', (WidgetTester tester) async {
    await tester.pumpWidget(
      componentHarness(
        const InstallTile(
          name: 'Main',
          color: IdentityColor.orange,
          progress: PhaseProgress(2),
        ),
      ),
    );
    final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    );
    expect(
      paints.any(
        (CustomPaint paint) => paint.painter is InstallTileRingPainter,
      ),
      isTrue,
    );
  });

  test('the painter repaints only when something changes', () {
    InstallTileRingPainter painter(TileProgress progress) =>
        InstallTileRingPainter(
          progress: progress,
          track: const Color(0xFF000000),
          fill: const Color(0xFFFFFFFF),
          radius: 10,
        );
    expect(
      painter(const PhaseProgress(1))
          .shouldRepaint(painter(const PhaseProgress(1))),
      isFalse,
    );
    expect(
      painter(const PhaseProgress(2))
          .shouldRepaint(painter(const PhaseProgress(1))),
      isTrue,
    );
    expect(
      painter(const FractionProgress(0.5))
          .shouldRepaint(painter(const FractionProgress(0.4))),
      isTrue,
    );
  });
}
