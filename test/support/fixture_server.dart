import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

sealed class Fault {
  const Fault();
}

final class StatusFault extends Fault {
  const StatusFault(this.status);

  final int status;
}

final class DropFault extends Fault {
  const DropFault(this.afterBytes);

  final int afterBytes;
}

final class StallFault extends Fault {
  const StallFault(this.afterBytes);

  final int afterBytes;
}

final class IgnoreRangeFault extends Fault {
  const IgnoreRangeFault();
}

final class RecordedRequest {
  const RecordedRequest({required this.method, required this.path, this.range});

  final String method;
  final String path;
  final String? range;
}

final class FixtureServer {
  FixtureServer._(this._server);

  static Future<FixtureServer> start() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final FixtureServer fixture = FixtureServer._(server);
    server.listen(fixture._handle);
    return fixture;
  }

  static final RegExp _range = RegExp(r'^bytes=(\d+)-$');

  final HttpServer _server;
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  final Map<String, Map<String, String>> _headers =
      <String, Map<String, String>>{};
  final Map<String, List<Fault>> _faults = <String, List<Fault>>{};
  final List<Socket> _stalled = <Socket>[];
  final List<RecordedRequest> requests = <RecordedRequest>[];

  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}/');

  void serve(
    String path,
    List<int> bytes, {
    Map<String, String> headers = const <String, String>{},
  }) {
    _files[path] = Uint8List.fromList(bytes);
    _headers[path] = headers;
  }

  void serveText(String path, String text) => serve(path, utf8.encode(text));

  void fault(String path, Fault fault) =>
      (_faults[path] ??= <Fault>[]).add(fault);

  int hits(String path) =>
      requests.where((RecordedRequest request) => request.path == path).length;

  Future<void> close() async {
    for (final Socket socket in _stalled) {
      socket.destroy();
    }
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final String path = request.uri.path.substring(1);
    final String? range = request.headers.value(HttpHeaders.rangeHeader);
    requests.add(
      RecordedRequest(method: request.method, path: path, range: range),
    );
    final List<Fault> queued = _faults[path] ?? <Fault>[];
    final Fault? fault = queued.isEmpty ? null : queued.removeAt(0);
    final HttpResponse response = request.response;
    final Uint8List? body = _files[path];
    if (fault is StatusFault || body == null) {
      response.statusCode = fault is StatusFault
          ? fault.status
          : HttpStatus.notFound;
      await response.close();
      return;
    }
    _headers[path]!.forEach(response.headers.set);
    final RegExpMatch? match = range == null || fault is IgnoreRangeFault
        ? null
        : _range.firstMatch(range);
    final int start = match == null ? 0 : int.parse(match[1]!);
    if (match != null) {
      if (start >= body.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${body.length - 1}/${body.length}',
      );
    }
    final Uint8List slice = Uint8List.sublistView(body, start);
    response.contentLength = slice.length;
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }
    final int? cut = switch (fault) {
      DropFault(:final int afterBytes) ||
      StallFault(:final int afterBytes) => min(afterBytes, slice.length),
      _ => null,
    };
    if (cut == null) {
      response.add(slice);
      await response.close();
      return;
    }
    final Socket socket = await response.detachSocket();
    socket.add(Uint8List.sublistView(slice, 0, cut));
    await socket.flush();
    if (fault is DropFault) {
      socket.destroy();
    } else {
      _stalled.add(socket);
    }
  }
}
