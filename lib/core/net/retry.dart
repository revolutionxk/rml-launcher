import 'dart:async';

import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

final class RetryPolicy {
  const RetryPolicy(this.delays);

  static const RetryPolicy standard = RetryPolicy(<Duration>[
    Duration(milliseconds: 500),
    Duration(milliseconds: 1500),
    Duration(seconds: 4),
    Duration(seconds: 10),
  ]);

  static const RetryPolicy none = RetryPolicy(<Duration>[]);

  final List<Duration> delays;

  int get attempts => delays.length + 1;
}

bool isRetryableStatus(int status) => status == 429 || status >= 500;

bool isRetryable(AppFailure failure) {
  if (failure is! NetworkFailure) {
    return false;
  }
  final int? status = failure.statusCode;
  return status == null || isRetryableStatus(status);
}

Future<Result<T>> withRetry<T>(
  RetryPolicy policy,
  Future<Result<T>> Function() attempt, {
  AbortSignal? abort,
  bool Function(AppFailure failure) retryable = isRetryable,
}) async {
  Result<T> result = await attempt();
  for (final Duration delay in policy.delays) {
    final AppFailure? failure = result.failureOrNull;
    if (failure == null || !retryable(failure)) {
      return result;
    }
    await Future.any(<Future<void>>[
      Future<void>.delayed(delay),
      if (abort != null) abort.whenAborted,
    ]);
    if (abort?.isAborted ?? false) {
      return Result<T>.err(const CancelledFailure());
    }
    result = await attempt();
  }
  return result;
}
