import 'dart:async';

final class ValueHub<T> {
  ValueHub(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    _value = next;
    if (!_changes.isClosed) {
      _changes.add(next);
    }
  }

  Stream<T> get changes => _changes.stream;

  Stream<T> watch() {
    StreamSubscription<T>? subscription;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_value);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () async {
        await subscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  Future<void> close() => _changes.close();
}
