import 'package:flutter/painting.dart';
import 'package:rml_launcher/design/components/pressable.dart';
import 'package:rml_launcher/design/tokens/colors.dart';

BoxDecoration? focusRing(
  ThemeColors colors,
  PressableState state,
  double radius,
) => state.focused
    ? BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.focus, width: 2),
      )
    : null;
