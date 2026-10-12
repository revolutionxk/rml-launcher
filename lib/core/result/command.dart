import 'package:flutter/foundation.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

abstract base class Command<T> extends ChangeNotifier {
  Command();

  bool _running = false;
  bool _disposed = false;
  Result<T>? _result;

  bool get running => _running;

  Result<T>? get result => _result;

  bool get completed => _result is Ok<T>;

  T? get value => _result?.valueOrNull;

  AppFailure? get failure => _result?.failureOrNull;

  void clearResult() {
    _result = null;
    _notify();
  }

  Future<void> run(Future<Result<T>> Function() action) async {
    if (_running) {
      return;
    }
    _running = true;
    _result = null;
    _notify();

    try {
      _result = await action();
    } catch (error, stackTrace) {
      _result = Result<T>.err(
        UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    } finally {
      _running = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

final class Command0<T> extends Command<T> {
  Command0(this._action);

  final Future<Result<T>> Function() _action;

  Future<void> execute() => run(_action);
}

final class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final Future<Result<T>> Function(A argument) _action;

  Future<void> execute(A argument) => run(() => _action(argument));
}
