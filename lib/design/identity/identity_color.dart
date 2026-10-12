import 'package:flutter/widgets.dart';

enum IdentityColor {
  orange(dark: Color(0xFFCC8553), light: Color(0xFF9E6033)),
  olive(dark: Color(0xFF92A14E), light: Color(0xFF6C792F)),
  jade(dark: Color(0xFF3CAE93), light: Color(0xFF14846D)),
  teal(dark: Color(0xFF20ADB1), light: Color(0xFF038285)),
  cyan(dark: Color(0xFF35A7C9), light: Color(0xFF087E9B)),
  violet(dark: Color(0xFF9C8BD6), light: Color(0xFF7565A6)),
  purple(dark: Color(0xFFB582C4), light: Color(0xFF8A5E97)),
  magenta(dark: Color(0xFFC77CAB), light: Color(0xFF995982)),
  graphite(dark: Color(0xFF92999F), light: Color(0xFF6C7278));

  const IdentityColor({required this.dark, required this.light});

  final Color dark;
  final Color light;

  Color fill(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color ink(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF0F1A23)
      : const Color(0xFFFFFFFF);
}
