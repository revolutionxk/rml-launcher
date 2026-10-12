import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_text.dart';

final class NativeException implements Exception {
  const NativeException(this.code, this.message);

  factory NativeException.last(int code) =>
      NativeException(code, readNativeText(bindings.rml_last_error()));

  final int code;
  final String message;

  @override
  String toString() => 'NativeException($code, $message)';
}
