import 'dart:async';

final class AbortSignal {
  AbortSignal();

  factory AbortSignal.linkedTo(AbortSignal parent) {
    final AbortSignal child = AbortSignal();
    if (parent.isAborted) {
      child.abort();
    } else {
      unawaited(parent.whenAborted.then((_) => child.abort()));
    }
    return child;
  }

  final Completer<void> _aborted = Completer<void>();

  bool get isAborted => _aborted.isCompleted;

  Future<void> get whenAborted => _aborted.future;

  void abort() {
    if (!_aborted.isCompleted) {
      _aborted.complete();
    }
  }
}
