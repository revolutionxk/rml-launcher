import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_exception.dart';
import 'package:rml_native/src/native_text.dart';

enum HashAlgorithm {
  md5(0, 32),
  sha256(1, 64);

  const HashAlgorithm(this.code, this.hexLength);

  final int code;
  final int hexLength;
}

String hashBytes(HashAlgorithm algorithm, Uint8List data) =>
    using((Arena arena) {
      final Pointer<Uint8> input = arena<Uint8>(data.isEmpty ? 1 : data.length);
      input.asTypedList(data.length).setAll(0, data);
      final int capacity = algorithm.hexLength + 1;
      final Pointer<Char> out = arena<Char>(capacity);
      final int status = bindings.rml_hash_bytes(
        algorithm.code,
        input,
        data.length,
        out,
        capacity,
      );
      if (status != 0) {
        throw NativeException.last(status);
      }
      return out.cast<Utf8>().toDartString();
    });

Future<String> hashFile(HashAlgorithm algorithm, String path) {
  final Completer<String> completer = Completer<String>();
  late final NativeCallable<Void Function(Int32, Pointer<Char>)> callable;
  callable = NativeCallable<Void Function(Int32, Pointer<Char>)>.listener((
    int status,
    Pointer<Char> text,
  ) {
    try {
      completer.complete(_hashResult(status, text));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      bindings.rml_free(text.cast());
      callable.close();
    }
  });
  final Pointer<Utf8> nativePath = path.toNativeUtf8();
  final int status;
  try {
    status = bindings.rml_hash_file_async(
      algorithm.code,
      nativePath.cast(),
      callable.nativeFunction,
    );
  } catch (_) {
    callable.close();
    rethrow;
  } finally {
    malloc.free(nativePath);
  }
  if (status != 0) {
    callable.close();
    completer.completeError(NativeException.last(status));
  }
  return completer.future;
}

String _hashResult(int status, Pointer<Char> text) {
  final String? message = text == nullptr ? null : readNativeText(text);
  if (status != 0) {
    throw NativeException(status, message ?? '');
  }
  if (message == null) {
    throw const NativeException(3, 'No result');
  }
  return message;
}
