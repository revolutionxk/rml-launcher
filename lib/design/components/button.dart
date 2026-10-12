import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/components/focus_ring.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/motion/motion.dart';
import 'package:rml_launcher/design/theme/theme.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

enum ButtonVariant { primary, secondary, quiet }

class Button extends StatelessWidget {
  const Button({
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.secondary,
    this.icon,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ThemeColors colors = theme.colors;
    final IconData? leading = icon;
    return Pressable(
      onPressed: onPressed,
      autofocus: autofocus,
      builder: (BuildContext context, PressableState state) {
        final Color foreground = !state.enabled
            ? colors.textOff
            : variant == ButtonVariant.primary
            ? colors.onAccent
            : colors.text;
        return AnimatedContainer(
          duration: theme.motion.press,
          curve: Easing.out,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _background(colors, state),
            borderRadius: BorderRadius.circular(6),
            border: variant == ButtonVariant.secondary
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

  Color _background(ThemeColors colors, PressableState state) {
    const Color clear = Color(0x00000000);
    return switch (variant) {
      ButtonVariant.primary when !state.enabled => colors.well,
      ButtonVariant.primary when state.pressed => Color.alphaBlend(
        colors.pressed,
        colors.accent,
      ),
      ButtonVariant.primary when state.hovered => Color.alphaBlend(
        colors.hover,
        colors.accent,
      ),
      ButtonVariant.primary => colors.accent,
      _ when state.pressed => colors.pressed,
      _ when state.hovered => colors.hover,
      _ => clear,
    };
  }
}
