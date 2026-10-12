import 'package:flutter/widgets.dart';
import 'package:rml_launcher/design/components/focus_ring.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';

class NavItem extends StatelessWidget {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final RmlThemeData theme = RmlTheme.of(context);
    final RmlColors colors = theme.colors;
    final String? hint = trailing;
    return Pressable(
      onPressed: onPressed,
      selected: selected,
      builder: (BuildContext context, PressableState state) {
        final Color foreground = selected ? colors.text : colors.text2;
        return AnimatedContainer(
          duration: state.hovered
              ? theme.motion.hoverIn
              : theme.motion.hoverOut,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.raised
                : state.pressed
                ? colors.pressed
                : state.hovered
                ? colors.hover
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(6),
          ),
          foregroundDecoration: focusRing(colors, state, 6),
          child: Row(
            children: <Widget>[
              Icon(selected ? selectedIcon : icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: theme.typography.micro.copyWith(color: colors.text3),
                ),
            ],
          ),
        );
      },
    );
  }
}
