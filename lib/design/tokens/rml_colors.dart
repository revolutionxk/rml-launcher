import 'package:flutter/widgets.dart';

enum RmlPalette { blackAndBlue, stoneAndSand, studioGrey }

final class RmlColors {
  const RmlColors({
    required this.chrome,
    required this.panel,
    required this.well,
    required this.card,
    required this.raised,
    required this.float,
    required this.line,
    required this.lineStrong,
    required this.hover,
    required this.pressed,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textOff,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.focus,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.scrim,
  });

  final Color chrome;
  final Color panel;
  final Color well;
  final Color card;
  final Color raised;
  final Color float;
  final Color line;
  final Color lineStrong;
  final Color hover;
  final Color pressed;
  final Color text;
  final Color text2;
  final Color text3;
  final Color textOff;
  final Color accent;
  final Color onAccent;
  final Color accentText;
  final Color focus;
  final Color ok;
  final Color warn;
  final Color danger;
  final Color scrim;

  static RmlColors of(RmlPalette palette, Brightness brightness) =>
      switch ((palette, brightness)) {
        (RmlPalette.blackAndBlue, Brightness.dark) => blackAndBlueDark,
        (RmlPalette.blackAndBlue, Brightness.light) => blackAndBlueLight,
        (RmlPalette.stoneAndSand, Brightness.dark) => stoneAndSandDark,
        (RmlPalette.stoneAndSand, Brightness.light) => stoneAndSandLight,
        (RmlPalette.studioGrey, Brightness.dark) => studioGreyDark,
        (RmlPalette.studioGrey, Brightness.light) => studioGreyLight,
      };

  static const RmlColors blackAndBlueDark = RmlColors(
    chrome: Color(0xFF141E26),
    panel: Color(0xFF1B2A35),
    well: Color(0xFF172530),
    card: Color(0xFF21303B),
    raised: Color(0xFF253541),
    float: Color(0xFF2D3E4B),
    line: Color(0x14C8E1F5),
    lineStrong: Color(0x24C8E1F5),
    hover: Color(0x0DC8E1F5),
    pressed: Color(0x14C8E1F5),
    text: Color(0xFFE6EDF2),
    text2: Color(0xFFC3D0DA),
    text3: Color(0xFFA2B5C4),
    textOff: Color(0xFF738596),
    accent: Color(0xFF6E99CA),
    onAccent: Color(0xFF0F1A23),
    accentText: Color(0xFF91B6DF),
    focus: Color(0xFF91B6DF),
    ok: Color(0xFF85C295),
    warn: Color(0xFFD7C59A),
    danger: Color(0xFFF59B91),
    scrim: Color(0x8C060B0F),
  );

  static const RmlColors blackAndBlueLight = RmlColors(
    chrome: Color(0xFFE0E8EE),
    panel: Color(0xFFF2F6F9),
    well: Color(0xFFE8EEF2),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    float: Color(0xFFFFFFFF),
    line: Color(0x171B2A35),
    lineStrong: Color(0x291B2A35),
    hover: Color(0x0D1B2A35),
    pressed: Color(0x141B2A35),
    text: Color(0xFF1B2A35),
    text2: Color(0xFF33495A),
    text3: Color(0xFF4E6375),
    textOff: Color(0xFF6F8191),
    accent: Color(0xFF335882),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF335882),
    focus: Color(0xFF335882),
    ok: Color(0xFF346B46),
    warn: Color(0xFF795C15),
    danger: Color(0xFFA24138),
    scrim: Color(0x471B2A35),
  );

  static const RmlColors stoneAndSandDark = RmlColors(
    chrome: Color(0xFF1F1D1E),
    panel: Color(0xFF272426),
    well: Color(0xFF221F21),
    card: Color(0xFF2C292B),
    raised: Color(0xFF302D2F),
    float: Color(0xFF353133),
    line: Color(0x14FFF8F0),
    lineStrong: Color(0x24FFF8F0),
    hover: Color(0x0DFFF8F0),
    pressed: Color(0x14FFF8F0),
    text: Color(0xFFE9E7E2),
    text2: Color(0xFFC9C6C1),
    text3: Color(0xFFAAA7A2),
    textOff: Color(0xFF7A7570),
    accent: Color(0xFF8DA7C7),
    onAccent: Color(0xFF1A1C21),
    accentText: Color(0xFFAABBD0),
    focus: Color(0xFFAABBD0),
    ok: Color(0xFF8CBF9F),
    warn: Color(0xFFD7C59A),
    danger: Color(0xFFD99792),
    scrim: Color(0x8C0C0A0B),
  );

  static const RmlColors stoneAndSandLight = RmlColors(
    chrome: Color(0xFFE4E2DF),
    panel: Color(0xFFF3F2F0),
    well: Color(0xFFEAE8E5),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    float: Color(0xFFFFFFFF),
    line: Color(0x17281E23),
    lineStrong: Color(0x29281E23),
    hover: Color(0x0D281E23),
    pressed: Color(0x14281E23),
    text: Color(0xFF2A2729),
    text2: Color(0xFF4B474A),
    text3: Color(0xFF605C5F),
    textOff: Color(0xFF8A8588),
    accent: Color(0xFF55657A),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF4E5F74),
    focus: Color(0xFF4E5F74),
    ok: Color(0xFF476452),
    warn: Color(0xFF75590F),
    danger: Color(0xFF874E4A),
    scrim: Color(0x42281E23),
  );

  static const RmlColors studioGreyDark = RmlColors(
    chrome: Color(0xFF232323),
    panel: Color(0xFF2B2B2B),
    well: Color(0xFF262626),
    card: Color(0xFF303030),
    raised: Color(0xFF343434),
    float: Color(0xFF383838),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    hover: Color(0x0DFFFFFF),
    pressed: Color(0x14FFFFFF),
    text: Color(0xFFECECEC),
    text2: Color(0xFFD2D2D2),
    text3: Color(0xFFB0B0B0),
    textOff: Color(0xFF777777),
    accent: Color(0xFF3D8BD8),
    onAccent: Color(0xFF0B1520),
    accentText: Color(0xFF7AB6F0),
    focus: Color(0xFF7AB6F0),
    ok: Color(0xFF6DC36F),
    warn: Color(0xFFE0AE52),
    danger: Color(0xFFFF9189),
    scrim: Color(0x80000000),
  );

  static const RmlColors studioGreyLight = RmlColors(
    chrome: Color(0xFFE6E6E6),
    panel: Color(0xFFF6F6F6),
    well: Color(0xFFECECEC),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    float: Color(0xFFFFFFFF),
    line: Color(0x14000000),
    lineStrong: Color(0x26000000),
    hover: Color(0x0B000000),
    pressed: Color(0x13000000),
    text: Color(0xFF1D1D1D),
    text2: Color(0xFF444444),
    text3: Color(0xFF5F5F5F),
    textOff: Color(0xFF8C8C8C),
    accent: Color(0xFF1E6DB8),
    onAccent: Color(0xFFFFFFFF),
    accentText: Color(0xFF0B61AB),
    focus: Color(0xFF0B61AB),
    ok: Color(0xFF066F1F),
    warn: Color(0xFF8A5200),
    danger: Color(0xFFB42B25),
    scrim: Color(0x3D000000),
  );
}
