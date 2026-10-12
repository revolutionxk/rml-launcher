import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

void main() {
  const RetryPolicy fast = RetryPolicy(<Duration>[
    Duration.zero,
    Duration.zero,
    Duration.zero,
    Duration.zero,
  ]);

  test('the standard policy makes five attempts', () {
    expect(RetryPolicy.standard.attempts, 5);
    expect(
      RetryPolicy.standard.delays.first,
      const Duration(milliseconds: 500),
    );
    expect(RetryPolicy.standard.delays.last, const Duration(seconds: 10));
  });

  test('retries network failures until one succeeds', () async {
    int calls = 0;
    final Result<int> result = await withRetry(fast, () async {
      calls++;
      return calls < 3
          ? const Result<int>.err(NetworkFailure(statusCode: 503))
          : const Result<int>.ok(7);
    });
    expect(result.valueOrNull, 7);
    expect(calls, 3);
  });

  test('a 404 is not retried', () async {
    int calls = 0;
    final Result<int> result = await withRetry(fast, () async {
      calls++;
      return const Result<int>.err(NetworkFailure(statusCode: 404));
    });
    expect(result.failureOrNull, isA<NetworkFailure>());
    expect(calls, 1);
  });

  test('gives up after the last attempt', () async {
    int calls = 0;
    await withRetry(fast, () async {
      calls++;
      return const Result<int>.err(NetworkFailure(isTimeout: true));
    });
    expect(calls, 5);
  });

  test('an abort stops the waiting', () async {
    final AbortSignal abort = AbortSignal();
    int calls = 0;
    final Future<Result<int>> pending = withRetry(
      const RetryPolicy(<Duration>[Duration(hours: 1)]),
      () async {
        calls++;
        return const Result<int>.err(NetworkFailure());
      },
      abort: abort,
    );
    abort.abort();
    expect((await pending).failureOrNull, isA<CancelledFailure>());
    expect(calls, 1);
  });

  test('retryable statuses are 429 and 5xx', () {
    expect(isRetryableStatus(429), isTrue);
    expect(isRetryableStatus(500), isTrue);
    expect(isRetryableStatus(404), isFalse);
    expect(isRetryable(const NetworkFailure()), isTrue);
    expect(isRetryable(const IoFailure(path: '/a')), isFalse);
  });
}
