import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class PressableState {
  const PressableState({
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.enabled,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool enabled;
}

typedef PressableBuilder = Widget Function(
  BuildContext context,
  PressableState state,
);

class Pressable extends StatefulWidget {
  const Pressable({
    required this.onPressed,
    required this.builder,
    this.semanticLabel,
    this.selected,
    this.autofocus = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final PressableBuilder builder;
  final String? semanticLabel;
  final bool? selected;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (ActivateIntent intent) {
        widget.onPressed?.call();
        return null;
      },
    ),
  };

  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    final PressableState state = PressableState(
      hovered: _hovered && enabled,
      pressed: _pressed && enabled,
      focused: _focused && enabled,
      enabled: enabled,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        shortcuts: _shortcuts,
        actions: _actions,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (bool value) => setState(() => _hovered = value),
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled
              ? (TapDownDetails details) => setState(() => _pressed = true)
              : null,
          onTapUp: enabled
              ? (TapUpDetails details) => setState(() => _pressed = false)
              : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: widget.builder(context, state),
        ),
      ),
    );
  }
}
