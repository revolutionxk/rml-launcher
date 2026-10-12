import 'package:flutter/painting.dart';

final class Typography {
  const Typography({
    required this.title,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.micro,
    required this.code,
  });

  static const String sans = 'SourceSans3';
  static const String mono = 'SourceCodePro';

  static const Typography standard = Typography(
    title: TextStyle(
      fontFamily: sans,
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    heading: TextStyle(
      fontFamily: sans,
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
    ),
    bodyStrong: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ),
    caption: TextStyle(
      fontFamily: sans,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
    ),
    micro: TextStyle(
      fontFamily: sans,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
    ),
    code: TextStyle(
      fontFamily: mono,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
    ),
  );

  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle micro;
  final TextStyle code;
}
