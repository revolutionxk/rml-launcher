import 'package:flutter/widgets.dart';

abstract final class RmlCurves {
  static const Curve out = Cubic(0.23, 1, 0.32, 1);
  static const Curve emphasized = Cubic(0.32, 0.72, 0, 1);
  static const Curve inOut = Cubic(0.77, 0, 0.175, 1);
}

final class RmlMotion {
  const RmlMotion({required this.reduced});

  final bool reduced;

  Duration get press => _movement(100);

  Duration get hoverIn => _movement(60);

  Duration get hoverOut => _movement(140);

  Duration get xs => _movement(100);

  Duration get sm => _movement(150);

  Duration get md => _movement(200);

  Duration get lg => _movement(260);

  Duration get fade => const Duration(milliseconds: 150);

  Duration _movement(int milliseconds) =>
      reduced ? Duration.zero : Duration(milliseconds: milliseconds);
}
