import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/design/identity/monogram.dart';
import 'package:rml_launcher/design/identity/tile_progress.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';

class InstallTile extends StatelessWidget {
  const InstallTile({
    required this.name,
    required this.color,
    this.monogram,
    this.glyph,
    this.size = 40,
    this.running = false,
    this.progress,
    this.surface,
    super.key,
  });

  final String name;
  final IdentityColor color;
  final String? monogram;
  final IconData? glyph;
  final double size;
  final bool running;
  final TileProgress? progress;
  final Color? surface;

  static const double _ringInset = 4;

  @override
  Widget build(BuildContext context) {
    final RmlThemeData theme = RmlTheme.of(context);
    final Brightness brightness = theme.brightness;
    final Color ink = IdentityColor.ink(brightness);
    final double radius = size * 0.22;
    final String letters = monogram ?? monogramFor(name);
    final IconData? face = glyph;
    final TileProgress? current = progress;
    final double dot = math.max(8, size * 0.24);
    return Semantics(
      container: true,
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.fill(brightness),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Center(
                  child: face != null
                      ? Icon(face, size: size * 0.5, color: ink)
                      : Text(
                          letters,
                          style: theme.typography.bodyStrong.copyWith(
                            fontSize:
                                size *
                                (letters.characters.length > 1 ? 0.36 : 0.44),
                            height: 1,
                            color: ink,
                          ),
                        ),
                ),
              ),
            ),
            if (current != null)
              Positioned(
                left: -_ringInset,
                top: -_ringInset,
                right: -_ringInset,
                bottom: -_ringInset,
                child: CustomPaint(
                  painter: InstallTileRingPainter(
                    progress: current,
                    track: theme.colors.lineStrong,
                    fill: theme.colors.accent,
                    radius: radius + _ringInset,
                  ),
                ),
              ),
            if (running)
              Positioned(
                key: const ValueKey<String>('install-tile-dot'),
                right: -2,
                bottom: -2,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: theme.colors.ok,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: surface ?? theme.colors.panel,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class InstallTileRingPainter extends CustomPainter {
  InstallTileRingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.radius,
  });

  static const double stroke = 2;

  final TileProgress progress;
  final Color track;
  final Color fill;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint trackPaint = _paint(track);
    final Paint fillPaint = _paint(fill);
    switch (progress) {
      case PhaseProgress(:final int completed):
        final List<(Offset, Offset)> sides = _sides(rect);
        for (int index = 0; index < sides.length; index++) {
          final (Offset start, Offset end) = sides[index];
          canvas.drawLine(
            start,
            end,
            index < completed ? fillPaint : trackPaint,
          );
        }
      case FractionProgress(:final double value):
        final Path path = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
        canvas.drawPath(path, trackPaint);
        final PathMetric metric = path.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * value),
          fillPaint,
        );
    }
  }

  Paint _paint(Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..color = color;

  List<(Offset, Offset)> _sides(Rect rect) => <(Offset, Offset)>[
    (
      Offset(rect.left + radius, rect.top),
      Offset(rect.right - radius, rect.top),
    ),
    (
      Offset(rect.right, rect.top + radius),
      Offset(rect.right, rect.bottom - radius),
    ),
    (
      Offset(rect.right - radius, rect.bottom),
      Offset(rect.left + radius, rect.bottom),
    ),
    (
      Offset(rect.left, rect.bottom - radius),
      Offset(rect.left, rect.top + radius),
    ),
  ];

  @override
  bool shouldRepaint(InstallTileRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill ||
      oldDelegate.radius != radius;
}
