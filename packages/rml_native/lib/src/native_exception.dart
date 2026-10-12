import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;

final class RmlNativeException implements Exception {
  const RmlNativeException(this.code, this.message);

  factory RmlNativeException.last(int code) => RmlNativeException(
    code,
    bindings.rml_last_error().cast<Utf8>().toDartString(),
  );

  final int code;
  final String message;

  @override
  String toString() => 'RmlNativeException($code, $message)';
}
