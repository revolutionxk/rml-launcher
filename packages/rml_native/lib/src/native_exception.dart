import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_text.dart';

final class RmlNativeException implements Exception {
  const RmlNativeException(this.code, this.message);

  factory RmlNativeException.last(int code) =>
      RmlNativeException(code, readNativeText(bindings.rml_last_error()));

  final int code;
  final String message;

  @override
  String toString() => 'RmlNativeException($code, $message)';
}
