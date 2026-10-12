import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/download/download_limiter.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_native/rml_native.dart' as rml;

import '../../../../support/fixture_server.dart';

const RetryPolicy fast = RetryPolicy(<Duration>[
  Duration.zero,
  Duration.zero,
  Duration.zero,
  Duration.zero,
]);

void main() {
  late FixtureServer server;
  late HttpClient client;
  late Directory dir;
  final Uint8List payload = Uint8List.fromList(
    List<int>.generate(300000, (int index) => index % 251),
  );
  final String md5 = rml.hashBytes(rml.HashAlgorithm.md5, payload);

  setUp(() async {
    server = await FixtureServer.start();
    client = createHttpClient();
    dir = await Directory.systemTemp.createTemp('rml download Ação ');
    server.serve('setup/pkg.zip', payload);
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    await dir.delete(recursive: true);
  });

  Downloader downloader({
    RetryPolicy retry = fast,
    Duration timeout = const Duration(seconds: 5),
  }) => Downloader(
    client: client,
    native: const FfiNativeService(),
    limiter: DownloadLimiter(4),
    retry: retry,
    readTimeout: timeout,
  );

  DownloadRequest request({String? hash}) => DownloadRequest(
    url: server.base.resolve('setup/pkg.zip'),
    path: p.join(dir.path, 'downloads', 'pkg.zip'),
    size: payload.length,
    md5: hash ?? md5,
  );

  File target() => File(p.join(dir.path, 'downloads', 'pkg.zip'));

  File partial() => File('${target().path}.partial');

  test('downloads and verifies a file', () async {
    int bytes = 0;
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (int delta) => bytes += delta,
    );
    expect(result.isOk, isTrue);
    expect(target().readAsBytesSync(), payload);
    expect(partial().existsSync(), isFalse);
    expect(bytes, payload.length);
  });

  test('concurrent downloads of one file share a single request', () async {
    final Downloader shared = downloader();
    int first = 0;
    int second = 0;
    final List<Result<void>> results = await Future.wait(<Future<Result<void>>>[
      shared.download(
        request(),
        abort: AbortSignal(),
        onBytes: (int delta) => first += delta,
      ),
      shared.download(
        request(),
        abort: AbortSignal(),
        onBytes: (int delta) => second += delta,
      ),
    ]);
    expect(results.every((Result<void> result) => result.isOk), isTrue);
    expect(server.hits('setup/pkg.zip'), 1);
    expect(first, payload.length);
    expect(second, payload.length);
    expect(target().readAsBytesSync(), payload);
  });

  test('a verified file is reused without a request', () async {
    target()
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(payload);
    int bytes = 0;
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (int delta) => bytes += delta,
    );
    expect(result.isOk, isTrue);
    expect(server.hits('setup/pkg.zip'), 0);
    expect(bytes, payload.length);
  });

  test('a damaged final file is replaced', () async {
    target()
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('damaged');
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.isOk, isTrue);
    expect(target().readAsBytesSync(), payload);
  });

  test('a dropped connection resumes with a range request', () async {
    server.fault('setup/pkg.zip', const DropFault(100000));
    int bytes = 0;
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (int delta) => bytes += delta,
    );
    expect(result.isOk, isTrue);
    expect(target().readAsBytesSync(), payload);
    expect(server.requests.last.range, startsWith('bytes='));
    expect(server.requests.last.range, isNot('bytes=0-'));
    expect(bytes, payload.length);
  });

  test('a partial left by an earlier run is continued', () async {
    partial()
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(payload.sublist(0, 1000));
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.isOk, isTrue);
    expect(server.requests.single.range, 'bytes=1000-');
    expect(target().readAsBytesSync(), payload);
  });

  test('a server that ignores the range restarts from zero', () async {
    partial()
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(payload.sublist(0, 1000));
    server.fault('setup/pkg.zip', const IgnoreRangeFault());
    int bytes = 0;
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (int delta) => bytes += delta,
    );
    expect(result.isOk, isTrue);
    expect(target().readAsBytesSync(), payload);
    expect(bytes, payload.length);
  });

  test('a complete partial answered with 416 is verified', () async {
    partial()
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(payload);
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.isOk, isTrue);
    expect(target().readAsBytesSync(), payload);
  });

  test('a 404 fails at once', () async {
    final Result<void> result = await downloader().download(
      DownloadRequest(
        url: server.base.resolve('setup/missing.zip'),
        path: p.join(dir.path, 'missing.zip'),
      ),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.statusCode,
        'status',
        404,
      ),
    );
    expect(server.hits('setup/missing.zip'), 1);
  });

  test('server errors are retried', () async {
    server
      ..fault('setup/pkg.zip', const StatusFault(503))
      ..fault('setup/pkg.zip', const StatusFault(500));
    final Result<void> result = await downloader().download(
      request(),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.isOk, isTrue);
    expect(server.hits('setup/pkg.zip'), 3);
  });

  test('a wrong md5 fails after the retries and leaves nothing', () async {
    final Result<void> result = await downloader().download(
      request(hash: '0' * 32),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.failureOrNull, isA<IntegrityFailure>());
    expect(server.hits('setup/pkg.zip'), 5);
    expect(target().existsSync(), isFalse);
    expect(partial().existsSync(), isFalse);
  });

  test('a stalled response times out', () async {
    server.fault('setup/pkg.zip', const StallFault(1000));
    final Result<void> result = await downloader(
      retry: RetryPolicy.none,
      timeout: const Duration(milliseconds: 300),
    ).download(request(), abort: AbortSignal(), onBytes: (_) {});
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.isTimeout,
        'timeout',
        isTrue,
      ),
    );
    expect(partial().lengthSync(), 1000);
  });

  test('a status followed by a stalled body times out', () async {
    server.fault('setup/pkg.zip', const StatusStallFault(503));
    final Result<void> result = await downloader(
      retry: RetryPolicy.none,
      timeout: const Duration(milliseconds: 300),
    ).download(request(), abort: AbortSignal(), onBytes: (_) {});
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.isTimeout,
        'timeout',
        isTrue,
      ),
    );
  });

  test(
    'an abort on a flowing transfer stops it and keeps the partial',
    () async {
      final Uint8List big = Uint8List(16 << 20);
      server.serve('setup/big.zip', big);
      final AbortSignal abort = AbortSignal();
      final Stopwatch watch = Stopwatch()..start();
      final Result<void> result = await downloader().download(
        DownloadRequest(
          url: server.base.resolve('setup/big.zip'),
          path: p.join(dir.path, 'big.zip'),
          size: big.length,
        ),
        abort: abort,
        onBytes: (int delta) {
          if (delta > 0) {
            abort.abort();
          }
        },
      );
      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      final File part = File(p.join(dir.path, 'big.zip.partial'));
      expect(part.existsSync(), isTrue);
      expect(part.lengthSync(), lessThan(big.length));
      expect(File(p.join(dir.path, 'big.zip')).existsSync(), isFalse);
    },
  );

  test(
    'an abort on a stalled transfer does not wait for the timeout',
    () async {
      server.fault('setup/pkg.zip', const StallFault(1000));
      final AbortSignal abort = AbortSignal();
      final Stopwatch watch = Stopwatch()..start();
      final Result<void> result =
          await downloader(
            retry: RetryPolicy.none,
            timeout: const Duration(seconds: 30),
          ).download(
            request(),
            abort: abort,
            onBytes: (int delta) {
              if (delta > 0) {
                abort.abort();
              }
            },
          );
      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(partial().existsSync(), isTrue);
    },
  );

  test('works with text bodies too', () async {
    server.serve('setup/a.txt', utf8.encode('hello'));
    final Result<void> result = await downloader().download(
      DownloadRequest(
        url: server.base.resolve('setup/a.txt'),
        path: p.join(dir.path, 'a.txt'),
        size: 5,
      ),
      abort: AbortSignal(),
      onBytes: (_) {},
    );
    expect(result.isOk, isTrue);
    expect(File(p.join(dir.path, 'a.txt')).readAsStringSync(), 'hello');
  });
}
