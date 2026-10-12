import 'dart:math';

final class TransferMeter {
  TransferMeter({
    required this.total,
    DateTime Function()? clock,
    this.window = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now {
    _sampledAt = _clock();
  }

  static const Duration _minimumSample = Duration(milliseconds: 200);

  final int total;
  final Duration window;
  final DateTime Function() _clock;
  late DateTime _sampledAt;
  int _done = 0;
  int _pending = 0;
  double _speed = 0;

  int get done => _done;

  double get speed => _speed;

  Duration? get eta {
    if (_speed <= 0) {
      return null;
    }
    final int remaining = max(0, total - _done);
    return Duration(microseconds: (remaining / _speed * 1e6).round());
  }

  void add(int bytes) {
    _done += bytes;
    if (bytes <= 0) {
      return;
    }
    _pending += bytes;
    final DateTime now = _clock();
    final Duration elapsed = now.difference(_sampledAt);
    if (elapsed < _minimumSample) {
      return;
    }
    final double seconds = elapsed.inMicroseconds / 1e6;
    final double instant = _pending / seconds;
    final double alpha = 1 - exp(-seconds / (window.inMicroseconds / 1e6));
    _speed = _speed == 0 ? instant : _speed + alpha * (instant - _speed);
    _pending = 0;
    _sampledAt = now;
  }
}
