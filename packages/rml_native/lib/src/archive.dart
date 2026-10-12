import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_exception.dart';
import 'package:rml_native/src/native_text.dart';

typedef ExtractProgress = void Function(int done, int total);

final class ExtractedFile {
  const ExtractedFile({required this.path, required this.size});

  final String path;
  final int size;
}

final class ExtractedArchive {
  const ExtractedArchive({required this.bytes, required this.files});

  factory ExtractedArchive.fromJson(Map<String, Object?> json) =>
      ExtractedArchive(
        bytes: json['bytes']! as int,
        files: <ExtractedFile>[
          for (final Object? item in json['files']! as List<Object?>)
            if (item case {'path': final String path, 'size': final int size})
              ExtractedFile(path: path, size: size),
        ],
      );

  final int bytes;
  final List<ExtractedFile> files;
}

Future<ExtractedArchive> extractZip(
  String archive,
  String destination, {
  ExtractProgress? onProgress,
}) {
  final Completer<ExtractedArchive> completer = Completer<ExtractedArchive>();
  final NativeCallable<Void Function(Uint64, Uint64)>? progress =
      onProgress == null
      ? null
      : NativeCallable<Void Function(Uint64, Uint64)>.listener(onProgress);
  late final NativeCallable<Void Function(Int32, Pointer<Char>)> finished;
  void closeCallables() {
    finished.close();
    progress?.close();
  }

  finished = NativeCallable<Void Function(Int32, Pointer<Char>)>.listener((
    int status,
    Pointer<Char> text,
  ) {
    try {
      completer.complete(_extraction(status, text));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      bindings.rml_free(text.cast());
      closeCallables();
    }
  });
  final Pointer<Utf8> nativeArchive = archive.toNativeUtf8();
  final Pointer<Utf8> nativeDestination = destination.toNativeUtf8();
  final int status;
  try {
    status = bindings.rml_zip_extract_async(
      nativeArchive.cast(),
      nativeDestination.cast(),
      progress?.nativeFunction ?? nullptr,
      finished.nativeFunction,
    );
  } catch (_) {
    closeCallables();
    rethrow;
  } finally {
    malloc
      ..free(nativeArchive)
      ..free(nativeDestination);
  }
  if (status != 0) {
    closeCallables();
    completer.completeError(NativeException.last(status));
  }
  return completer.future;
}

ExtractedArchive _extraction(int status, Pointer<Char> text) {
  final String? message = text == nullptr ? null : readNativeText(text);
  if (status != 0) {
    throw NativeException(status, message ?? '');
  }
  if (message == null) {
    throw const NativeException(3, 'No result');
  }
  return ExtractedArchive.fromJson(jsonDecode(message) as Map<String, Object?>);
}
