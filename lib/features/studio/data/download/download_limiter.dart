import 'dart:async';
import 'dart:collection';

final class DownloadLimiter {
  DownloadLimiter(this.slots);

  final int slots;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  int _active = 0;

  Future<T> run<T>(Future<T> Function() body) async {
    await _acquire();
    try {
      return await body();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < slots) {
      _active++;
      return Future<void>.value();
    }
    final Completer<void> slot = Completer<void>();
    _waiting.add(slot);
    return slot.future;
  }

  void _release() {
    if (_waiting.isEmpty) {
      _active--;
    } else {
      _waiting.removeFirst().complete();
    }
  }
}
