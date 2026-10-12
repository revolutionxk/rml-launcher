import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/core/platform/window_chrome.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/icons/rml_icons.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/shell/view/drag_area.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: <Widget>[
        const Expanded(child: DragArea(child: SizedBox.expand())),
        if (defaultTargetPlatform != TargetPlatform.macOS)
          const _WindowButtons(),
      ],
    ),
  );
}

class _WindowButtons extends ConsumerWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WindowChrome chrome = ref.watch(windowChromeProvider);
    final Translations t = context.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _WindowButton(
          icon: RmlIcons.minus,
          label: t.window.minimize,
          onPressed: chrome.minimize,
        ),
        _WindowButton(
          icon: RmlIcons.square,
          label: t.window.maximize,
          onPressed: chrome.toggleMaximize,
        ),
        _WindowButton(
          icon: RmlIcons.x,
          label: t.window.close,
          onPressed: chrome.close,
          destructive: true,
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final RmlColors colors = RmlTheme.of(context).colors;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (BuildContext context, PressableState state) {
        final bool active = state.hovered || state.pressed;
        return Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          color: active
              ? (destructive ? const Color(0xFFC42B1C) : colors.hover)
              : const Color(0x00000000),
          child: Icon(
            icon,
            size: 14,
            color: destructive && active
                ? const Color(0xFFFFFFFF)
                : colors.text2,
          ),
        );
      },
    );
  }
}
