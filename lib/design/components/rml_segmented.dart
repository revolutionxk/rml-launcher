import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/components/focus_ring.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/motion/rml_motion.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

final class RmlSegment<T> {
  const RmlSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class RmlSegmented<T> extends StatelessWidget {
  const RmlSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final List<RmlSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final RmlThemeData theme = RmlTheme.of(context);
    final RmlColors colors = theme.colors;
    final ValueChanged<T>? handler = onChanged;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colors.well,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final RmlSegment<T> segment in segments)
              Pressable(
                selected: segment.value == selected,
                onPressed: handler == null
                    ? null
                    : () => handler(segment.value),
                builder: (BuildContext context, PressableState state) {
                  final bool isSelected = segment.value == selected;
                  return AnimatedContainer(
                    duration: theme.motion.sm,
                    curve: RmlCurves.out,
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.raised
                          : state.hovered
                          ? colors.hover
                          : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? colors.lineStrong
                            : const Color(0x00000000),
                      ),
                    ),
                    foregroundDecoration: focusRing(colors, state, 6),
                    child: Text(
                      segment.label,
                      style: theme.typography.bodyStrong.copyWith(
                        fontSize: 13,
                        color: isSelected ? colors.text : colors.text3,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
