import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rml_launcher/core/config/app_info.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

const Duration readTimeout = Duration(seconds: 20);

HttpClient createHttpClient() => HttpClient()
  ..connectionTimeout = const Duration(seconds: 10)
  ..userAgent = 'RML Launcher/${AppInfo.version}';

final class RemoteFile {
  const RemoteFile({this.size, this.etag});

  final int? size;
  final String? etag;
}

NetworkFailure networkFailureOf(Object error, StackTrace stackTrace) =>
    NetworkFailure(
      isTimeout: error is TimeoutException,
      cause: error,
      stackTrace: stackTrace,
    );

Future<Result<String>> fetchText(
  HttpClient client,
  Uri url, {
  RetryPolicy retry = RetryPolicy.standard,
  Duration readTimeout = readTimeout,
}) => withRetry(retry, () => _send(client, 'GET', url, readTimeout, _body));

Future<Result<RemoteFile>> fetchHead(
  HttpClient client,
  Uri url, {
  RetryPolicy retry = RetryPolicy.standard,
  Duration readTimeout = readTimeout,
}) => withRetry(retry, () => _send(client, 'HEAD', url, readTimeout, _head));

Future<String> _body(HttpClientResponse response, Duration readTimeout) =>
    response.timeout(readTimeout).transform(utf8.decoder).join();

Future<RemoteFile> _head(
  HttpClientResponse response,
  Duration readTimeout,
) async {
  await response.timeout(readTimeout).drain<void>();
  return RemoteFile(
    size: response.contentLength < 0 ? null : response.contentLength,
    etag: response.headers.value(HttpHeaders.etagHeader),
  );
}

Future<Result<T>> _send<T>(
  HttpClient client,
  String method,
  Uri url,
  Duration readTimeout,
  Future<T> Function(HttpClientResponse response, Duration readTimeout) read,
) async {
  HttpClientRequest? request;
  try {
    request = await client.openUrl(method, url);
    final HttpClientResponse response = await request.close().timeout(
      readTimeout,
    );
    if (response.statusCode != HttpStatus.ok) {
      await response.timeout(readTimeout).drain<void>();
      return Result<T>.err(NetworkFailure(statusCode: response.statusCode));
    }
    return Result<T>.ok(await read(response, readTimeout));
  } on TimeoutException catch (error, stackTrace) {
    request?.abort();
    return Result<T>.err(networkFailureOf(error, stackTrace));
  } on IOException catch (error, stackTrace) {
    return Result<T>.err(networkFailureOf(error, stackTrace));
  } on FormatException catch (error, stackTrace) {
    return Result<T>.err(networkFailureOf(error, stackTrace));
  }
}
