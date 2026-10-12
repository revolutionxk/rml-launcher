import 'dart:async';
import 'dart:io';

import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/download/download_limiter.dart';

final class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.path,
    this.size,
    this.md5,
  });

  final Uri url;
  final String path;
  final int? size;
  final String? md5;
}

final class Downloader {
  Downloader({
    required this._client,
    required this._native,
    required this._limiter,
    this._retry = RetryPolicy.standard,
    this._readTimeout = readTimeout,
  });

  final HttpClient _client;
  final NativeService _native;
  final DownloadLimiter _limiter;
  final RetryPolicy _retry;
  final Duration _readTimeout;

  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  Future<Result<void>> download(
    DownloadRequest request, {
    required AbortSignal abort,
    required void Function(int delta) onBytes,
  }) async {
    final Future<void>? previous = _inFlight[request.path];
    final Completer<void> done = Completer<void>();
    _inFlight[request.path] = done.future;
    try {
      if (previous != null) {
        await Future.any(<Future<void>>[previous, abort.whenAborted]);
        if (abort.isAborted) {
          return const Result<void>.err(CancelledFailure());
        }
      }
      return await _download(request, abort: abort, onBytes: onBytes);
    } finally {
      unawaited(
        (previous ?? Future<void>.value()).then((_) {
          done.complete();
          if (identical(_inFlight[request.path], done.future)) {
            _inFlight.remove(request.path);
          }
        }),
      );
    }
  }

  Future<Result<void>> _download(
    DownloadRequest request, {
    required AbortSignal abort,
    required void Function(int delta) onBytes,
  }) async {
    int reported = 0;
    void sync(int onDisk) {
      onBytes(onDisk - reported);
      reported = onDisk;
    }

    final File target = File(request.path);
    final Result<bool> reusable = await _isVerified(target, request);
    if (reusable.isErr) {
      return Result<void>.err(reusable.failureOrNull!);
    }
    if (reusable.valueOrNull!) {
      sync(target.lengthSync());
      return const Result<void>.ok(null);
    }
    return withRetry(
      _retry,
      () => _limiter.run(() => _attempt(request, abort, sync)),
      abort: abort,
      retryable: _retryable,
    );
  }

  static bool _retryable(AppFailure failure) =>
      failure is IntegrityFailure ||
      (failure is NetworkFailure &&
          (failure.statusCode == null ||
              failure.statusCode == HttpStatus.requestedRangeNotSatisfiable ||
              isRetryableStatus(failure.statusCode!)));

  Future<Result<bool>> _isVerified(File file, DownloadRequest request) async {
    if (!file.existsSync()) {
      return const Result<bool>.ok(false);
    }
    final int? size = request.size;
    final String? md5 = request.md5;
    bool verified = size == null || file.lengthSync() == size;
    if (verified && md5 != null) {
      final Result<String> hash = await _native.hashFile(
        HashAlgorithm.md5,
        file.path,
      );
      if (hash.isErr) {
        return Result<bool>.err(hash.failureOrNull!);
      }
      verified = hash.valueOrNull == md5;
    }
    if (!verified) {
      try {
        await file.delete();
      } on FileSystemException catch (error, stackTrace) {
        return Result<bool>.err(
          IoFailure(path: file.path, cause: error, stackTrace: stackTrace),
        );
      }
    }
    return Result<bool>.ok(verified);
  }

  Future<Result<void>> _attempt(
    DownloadRequest request,
    AbortSignal abort,
    void Function(int onDisk) sync,
  ) async {
    if (abort.isAborted) {
      return const Result<void>.err(CancelledFailure());
    }
    final File partial = File('${request.path}.partial');
    try {
      await partial.parent.create(recursive: true);
      final int existing = partial.existsSync() ? partial.lengthSync() : 0;
      sync(existing);
      final HttpClientRequest pending = await _client.getUrl(request.url);
      if (existing > 0) {
        pending.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      unawaited(
        abort.whenAborted.then((_) => pending.abort(const CancelledFailure())),
      );
      final HttpClientResponse response = await pending.close().timeout(
        _readTimeout,
        onTimeout: () {
          pending.abort();
          throw TimeoutException(null, _readTimeout);
        },
      );
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await _drain(response, abort);
        if (abort.isAborted) {
          return const Result<void>.err(CancelledFailure());
        }
        if (existing > 0 && existing == request.size) {
          return await _verify(partial, request, sync);
        }
        if (partial.existsSync()) {
          await partial.delete();
        }
        sync(0);
        return const Result<void>.err(
          NetworkFailure(statusCode: HttpStatus.requestedRangeNotSatisfiable),
        );
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await _drain(response, abort);
        if (abort.isAborted) {
          return const Result<void>.err(CancelledFailure());
        }
        return Result<void>.err(
          NetworkFailure(statusCode: response.statusCode),
        );
      }
      final bool resumed =
          response.statusCode == HttpStatus.partialContent && existing > 0;
      int written = resumed ? existing : 0;
      sync(written);
      final RandomAccessFile file;
      try {
        file = await partial.open(
          mode: resumed ? FileMode.append : FileMode.write,
        );
      } on FileSystemException {
        await response.listen(null).cancel();
        rethrow;
      }
      final StreamIterator<List<int>> body = StreamIterator<List<int>>(
        response.timeout(_readTimeout),
      );
      unawaited(abort.whenAborted.then((_) => body.cancel()));
      try {
        while (true) {
          final bool more = await body.moveNext();
          if (abort.isAborted) {
            return const Result<void>.err(CancelledFailure());
          }
          if (!more) {
            break;
          }
          final List<int> chunk = body.current;
          await file.writeFrom(chunk);
          written += chunk.length;
          sync(written);
        }
      } finally {
        await body.cancel();
        await file.close();
      }
      return await _verify(partial, request, sync);
    } on CancelledFailure {
      return const Result<void>.err(CancelledFailure());
    } on FileSystemException catch (error, stackTrace) {
      return Result<void>.err(
        IoFailure(path: partial.path, cause: error, stackTrace: stackTrace),
      );
    } on TimeoutException catch (error, stackTrace) {
      if (abort.isAborted) {
        return const Result<void>.err(CancelledFailure());
      }
      return Result<void>.err(networkFailureOf(error, stackTrace));
    } on IOException catch (error, stackTrace) {
      if (abort.isAborted) {
        return const Result<void>.err(CancelledFailure());
      }
      return Result<void>.err(networkFailureOf(error, stackTrace));
    }
  }

  Future<void> _drain(HttpClientResponse response, AbortSignal abort) async {
    final StreamIterator<List<int>> body = StreamIterator<List<int>>(
      response.timeout(_readTimeout),
    );
    unawaited(abort.whenAborted.then((_) => body.cancel()));
    try {
      while (await body.moveNext()) {}
    } finally {
      await body.cancel();
    }
  }

  Future<Result<void>> _verify(
    File partial,
    DownloadRequest request,
    void Function(int onDisk) sync,
  ) async {
    final int length = partial.lengthSync();
    final int? size = request.size;
    if (size != null && length != size) {
      return _reject(
        partial,
        sync,
        expected: '$size bytes',
        actual: '$length bytes',
      );
    }
    final String? md5 = request.md5;
    if (md5 != null) {
      final Result<String> hash = await _native.hashFile(
        HashAlgorithm.md5,
        partial.path,
      );
      final String? actual = hash.valueOrNull;
      if (actual == null) {
        return Result<void>.err(hash.failureOrNull!);
      }
      if (actual != md5) {
        return _reject(partial, sync, expected: md5, actual: actual);
      }
    }
    await partial.rename(request.path);
    return const Result<void>.ok(null);
  }

  Future<Result<void>> _reject(
    File partial,
    void Function(int onDisk) sync, {
    required String expected,
    required String actual,
  }) async {
    await partial.delete();
    sync(0);
    return Result<void>.err(
      IntegrityFailure(expected: expected, actual: actual),
    );
  }
}
