import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/command.dart';
import 'package:rml_launcher/core/result/result.dart';

void main() {
  test('ignores re-entry while running and keeps the result', () async {
    final Completer<Result<int>> gate = Completer<Result<int>>();
    int calls = 0;
    final Command0<int> command = Command0<int>(() {
      calls++;
      return gate.future;
    });

    final Future<void> first = command.execute();
    final Future<void> second = command.execute();
    expect(command.running, isTrue);

    gate.complete(const Result<int>.ok(1));
    await Future.wait(<Future<void>>[first, second]);

    expect(calls, 1);
    expect(command.running, isFalse);
    expect(command.completed, isTrue);
    expect(command.value, 1);
  });

  test('exposes the failure and can be cleared', () async {
    final Command1<int, String> command = Command1<int, String>(
      (String input) async =>
          const Result<int>.err(ValidationFailure(message: 'bad')),
    );

    await command.execute('x');
    expect(command.failure, isA<ValidationFailure>());

    command.clearResult();
    expect(command.result, isNull);
  });

  test('a throwing action becomes an unknown failure', () async {
    final Command0<int> command = Command0<int>(
      () async => throw StateError('boom'),
    );

    await command.execute();

    expect(command.failure, isA<UnknownFailure>());
    expect(command.running, isFalse);
  });

  test('an action finishing after dispose does not throw', () async {
    final Completer<Result<int>> gate = Completer<Result<int>>();
    final Command0<int> command = Command0<int>(() => gate.future);

    final Future<void> pending = command.execute();
    command.dispose();
    gate.complete(const Result<int>.ok(1));

    await expectLater(pending, completes);
  });
}
