import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/components/focus_ring.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/motion/rml_motion.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

enum RmlButtonVariant { primary, secondary, quiet }

class RmlButton extends StatelessWidget {
  const RmlButton({
    required this.label,
    required this.onPressed,
    this.variant = RmlButtonVariant.secondary,
    this.icon,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final RmlButtonVariant variant;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final RmlThemeData theme = RmlTheme.of(context);
    final RmlColors colors = theme.colors;
    final IconData? leading = icon;
    return Pressable(
      onPressed: onPressed,
      autofocus: autofocus,
      builder: (BuildContext context, PressableState state) {
        final Color foreground = !state.enabled
            ? colors.textOff
            : variant == RmlButtonVariant.primary
            ? colors.onAccent
            : colors.text;
        return AnimatedContainer(
          duration: theme.motion.press,
          curve: RmlCurves.out,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _background(colors, state),
            borderRadius: BorderRadius.circular(6),
            border: variant == RmlButtonVariant.secondary
                ? Border.all(color: colors.lineStrong)
                : null,
          ),
          foregroundDecoration: focusRing(colors, state, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                Icon(leading, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.typography.bodyStrong.copyWith(color: foreground),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _background(RmlColors colors, PressableState state) {
    const Color clear = Color(0x00000000);
    return switch (variant) {
      RmlButtonVariant.primary when !state.enabled => colors.well,
      RmlButtonVariant.primary when state.pressed => Color.alphaBlend(
        colors.pressed,
        colors.accent,
      ),
      RmlButtonVariant.primary when state.hovered => Color.alphaBlend(
        colors.hover,
        colors.accent,
      ),
      RmlButtonVariant.primary => colors.accent,
      _ when state.pressed => colors.pressed,
      _ when state.hovered => colors.hover,
      _ => clear,
    };
  }
}
