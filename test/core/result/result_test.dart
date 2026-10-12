import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

void main() {
  test('ok carries its value', () {
    const Result<int> result = Result<int>.ok(4);
    expect(result.isOk, isTrue);
    expect(result.valueOrNull, 4);
    expect(result.failureOrNull, isNull);
  });

  test('err carries its failure', () {
    const AppFailure failure = NotFoundFailure(what: 'settings');
    const Result<int> result = Result<int>.err(failure);
    expect(result.isErr, isTrue);
    expect(result.valueOrNull, isNull);
    expect(result.failureOrNull, same(failure));
  });

  test('fold picks the matching branch', () {
    const Result<int> ok = Result<int>.ok(2);
    const Result<int> err = Result<int>.err(CancelledFailure());
    expect(
      ok.fold(onOk: (int v) => 'ok $v', onErr: (AppFailure f) => 'err'),
      'ok 2',
    );
    expect(
      err.fold(onOk: (int v) => 'ok $v', onErr: (AppFailure f) => 'err'),
      'err',
    );
  });

  test('map transforms only ok values', () {
    expect(const Result<int>.ok(2).map((int v) => v * 3).valueOrNull, 6);
    expect(
      const Result<int>.err(CancelledFailure()).map((int v) => v * 3).isErr,
      isTrue,
    );
  });

  test('flatMap chains async results', () async {
    final Result<String> chained = await const Result<int>.ok(2)
        .flatMap((int v) async => Result<String>.ok('v$v'));
    expect(chained.valueOrNull, 'v2');
  });

  test('unwrap throws the failure', () {
    expect(
      () => const Result<int>.err(CancelledFailure()).unwrap(),
      throwsA(isA<CancelledFailure>()),
    );
  });
}
